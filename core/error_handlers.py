import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from core.middleware import request_id_ctx

logger = logging.getLogger(__name__)


def _request_id(request: Request) -> str:
    # Prefer the value RequestIDMiddleware attached to ASGI scope state; fall
    # back to the contextvar for code paths that don't have a Request handy.
    return request.scope.get("state", {}).get("request_id") or request_id_ctx.get()


def register_exception_handlers(app: FastAPI) -> None:
    """
    Centralizes error handling so every error response - expected (404/403) or
    unexpected (an unhandled exception deep in a service) - comes back as the
    same JSON envelope, and so that unhandled exceptions never leak internal
    detail (stack traces, exception messages, file paths, connection strings)
    to the client. Full detail is always logged server-side, tagged with the
    same request id the client receives, so an on-call engineer can correlate
    a client-reported failure with the real server-side log line.
    """

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(request: Request, exc: StarletteHTTPException):
        request_id = _request_id(request)
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": {"detail": exc.detail, "request_id": request_id}},
            headers=getattr(exc, "headers", None),
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError):
        request_id = _request_id(request)
        # Pydantic error objects aren't JSON-serializable as-is (may contain
        # exception instances in "ctx") - reduce to plain, safe primitives only.
        errors = [
            {"loc": err.get("loc"), "msg": err.get("msg"), "type": err.get("type")}
            for err in exc.errors()
        ]
        return JSONResponse(
            status_code=422,
            content={"error": {"detail": "Request validation failed.", "errors": errors, "request_id": request_id}},
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        request_id = _request_id(request)
        logger.exception(
            "Unhandled exception on %s %s [request_id=%s]",
            request.method, request.url.path, request_id,
        )
        return JSONResponse(
            status_code=500,
            content={
                "error": {
                    "detail": "An unexpected error occurred. Contact support with this request_id.",
                    "request_id": request_id,
                }
            },
        )
