import logging

import httpx

from core.ollama_client import EMBED_MODEL, get_ollama_host

logger = logging.getLogger(__name__)

class EmbeddingGenerator:
    async def generate(self, text: str) -> list[float]:
        """Calls the Ollama API to generate vector embeddings."""
        payload = {
            "model": EMBED_MODEL,
            "prompt": text
        }

        async with httpx.AsyncClient() as client:
            try:
                api_url = f"{get_ollama_host()}/api/embeddings"
                response = await client.post(api_url, json=payload, timeout=15.0)
                response.raise_for_status()
                data = response.json()
                return data["embedding"]
            except httpx.HTTPError as e:
                logger.error(f"Ollama Embedding Error: {e}")
                raise

embedding_generator = EmbeddingGenerator()
