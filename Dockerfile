# syntax=docker/dockerfile:1

# ---- Builder stage: compile/install Python dependencies only ----
# Kept entirely separate from the runtime stage so build tools, pip's cache,
# and any sdist build artifacts never end up in the shipped image.
FROM python:3.12-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ---- Runtime stage: minimal image actually shipped/run ----
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/usr/local/bin:${PATH}"

# Unprivileged, no-login user - this process never needs root, and running
# as root in a container is an unnecessary privilege-escalation surface if
# the app or any dependency is ever compromised.
RUN groupadd --system Vela && useradd --system --gid Vela --no-create-home Vela

WORKDIR /app

# Only the installed Python packages come from the builder stage - no build
# tools, no pip cache, no intermediate layers.
COPY --from=builder /install /usr/local

COPY --chown=Vela:Vela . .

USER Vela

EXPOSE 8000

# Talks to the new liveness endpoint (core/middleware.py's request handling +
# app.py's /live) rather than /health, since /live never touches Mongo/
# Milvus/Ollama - a dependency outage should not also make Docker think the
# process itself is unhealthy and restart it in a loop that won't fix anything.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/live', timeout=3).status == 200 else 1)"

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]

