import logging

import httpx

from core.config import settings

logger = logging.getLogger(__name__)

_resolved_host: str | None = None


def resolve_ollama_host(hosts: list[str]) -> str:
    """
    Iterates through provided hosts and returns the first healthy one.
    All hosts come from settings.OLLAMA_HOSTS.
    """
    if not hosts:
        logger.error("No OLLAMA_HOSTS provided in .env")
        raise RuntimeError("OLLAMA_HOSTS is empty. Cannot resolve Ollama host.")

    with httpx.Client(timeout=2.0) as client:
        for host in hosts:
            try:
                response = client.get(host)
                if response.status_code == 200:
                    logger.info(f"Resolved Ollama host: {host}")
                    return host
                else:
                    logger.warning(f"Ollama host responded with {response.status_code}: {host}")
            except httpx.RequestError as e:
                logger.warning(f"Ollama host unreachable: {host} | Error: {e}")

    logger.error("No Ollama hosts available. All hosts failed health check.")
    raise RuntimeError("All OLLAMA_HOSTS failed. Cannot initialize Ollama.")


def get_ollama_host() -> str:
    """
    Resolves the active Ollama host, caching the result after the first call.
    Deliberately NOT resolved at import time: a health-checking network call
    (resolve_ollama_host) that raises on failure would otherwise crash the whole
    app at startup if Ollama happens to be briefly unreachable, instead of just
    the RAG/embedding features that actually depend on it.
    """
    global _resolved_host
    if _resolved_host is None:
        _resolved_host = (
            settings.OLLAMA_URI
            if settings.OLLAMA_URI
            else resolve_ollama_host(settings.ollama_hosts_list)
        )
    return _resolved_host


EMBED_MODEL = settings.EMBED_MODEL
LLM_MODEL = settings.LLM_MODEL
