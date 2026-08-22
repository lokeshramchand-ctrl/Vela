import uuid
from contextvars import ContextVar

from fastapi import HTTPException
from fastapi.responses import JSONResponse

# Bound per-request so log records can include the request id without threading
# it through every function signature.
request_id_ctx: ContextVar[str] = ContextVar("request_id", default="-")


class RequestIDMiddleware:
    """
    Pure ASGI middleware: assigns a request id (reusing an inbound X-Request-ID
    if the caller/proxy already set one), exposes it via request.state and a
    contextvar for logging, and echoes it back as a response header so a client
    or on-call engineer can correlate a specific failure with server-side logs.
    """

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        headers = dict(scope.get("headers") or [])
        request_id = headers.get(b"x-request-id", b"").decode() or str(uuid.uuid4())
        scope.setdefault("state", {})
        scope["state"]["request_id"] = request_id
        token = request_id_ctx.set(request_id)

        async def send_with_header(message):
            if message["type"] == "http.response.start":
                message.setdefault("headers", [])
                message["headers"].append((b"x-request-id", request_id.encode()))
            await send(message)

        try:
            await self.app(scope, receive, send_with_header)
        finally:
            request_id_ctx.reset(token)


class SecurityHeadersMiddleware:
    """
    Adds baseline defensive response headers. This is a headless JSON API with
    no HTML rendering and no browser-facing frontend, so a full CSP/HSTS policy
    belongs at the TLS-terminating reverse proxy/load balancer in front of this
    service (documented in docs/14-deployment-operations.md), not here. The
    headers below are cheap, always-correct defaults regardless of what sits in
    front of this process.
    """

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        async def send_with_headers(message):
            if message["type"] == "http.response.start":
                headers = message.setdefault("headers", [])
                headers.extend([
                    (b"x-content-type-options", b"nosniff"),
                    (b"x-frame-options", b"DENY"),
                    (b"referrer-policy", b"no-referrer"),
                    (b"permissions-policy", b"geolocation=(), microphone=(), camera=()"),
                    (b"cross-origin-resource-policy", b"same-origin"),
                ])
            await send(message)

        await self.app(scope, receive, send_with_headers)


class BodySizeLimitMiddleware:
    """
    Rejects oversized request bodies before they're ever fully read into memory
    (CWE-400 uncontrolled resource consumption). Two layers, since Content-Length
    can be omitted entirely (chunked transfer-encoding):
      1. Immediate rejection if a declared Content-Length exceeds the limit.
      2. A running byte counter on the actual ASGI receive channel that aborts
         the request the moment more than max_bytes has actually been streamed,
         even if no Content-Length header was sent at all.
    """

    def __init__(self, app, max_bytes: int):
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        headers = dict(scope.get("headers") or [])
        content_length = headers.get(b"content-length")
        if content_length is not None:
            try:
                if int(content_length) > self.max_bytes:
                    response = JSONResponse(
                        status_code=413,
                        content={"error": "payload_too_large", "detail": "Request body exceeds the maximum allowed size."},
                    )
                    await response(scope, receive, send)
                    return
            except ValueError:
                pass

        total_received = 0

        async def limited_receive():
            nonlocal total_received
            message = await receive()
            if message["type"] == "http.request":
                total_received += len(message.get("body", b""))
                if total_received > self.max_bytes:
                    raise HTTPException(status_code=413, detail="Request body exceeds the maximum allowed size.")
            return message

        await self.app(scope, limited_receive, send)
