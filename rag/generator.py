import json
import logging
from typing import Any

import httpx

from core.ollama_client import LLM_MODEL, get_ollama_host

logger = logging.getLogger(__name__)

class ExplanationGenerator:
    def __init__(self):
        self.system_prompt = """
You are the Vela Transaction Intelligence Reasoning Engine.
Your ONLY purpose is to explain transaction categorizations or recommend financial insights based STRICTLY on the provided XML context.

RULES:
1. DO NOT act like a chatbot. Do not say "Hello", "Sure", or "I can help with that."
2. DO NOT hallucinate. If the context does not contain the answer, output: {"error": "Insufficient data to explain."}
3. ALWAYS output your response in valid JSON format matching this schema:
{
    "explanation": "Concise reasoning here...",
    "confidence_in_explanation": "HIGH|MEDIUM|LOW",
    "primary_data_source": "Merchant Name or ID"
}
"""

    async def generate_explanation(self, query: str, context_string: str) -> dict[str, Any]:
        if context_string == "NO_CONTEXT_AVAILABLE":
            return {"error": "No historical behavior found to explain this transaction."}

        full_prompt = f"CONTEXT:\n{context_string}\n\nUSER QUERY: {query}\n\nOUTPUT STRICT JSON:"

        payload = {
            "model": LLM_MODEL,
            "system": self.system_prompt,
            "prompt": full_prompt,
            "stream": False,
            "format": "json" # Forces Ollama to output valid JSON
        }

        async with httpx.AsyncClient() as client:
            try:
                api_url = f"{get_ollama_host()}/api/generate"
                response = await client.post(api_url, json=payload, timeout=30.0)
                response.raise_for_status()
                data = response.json()

                # Parse the JSON string returned by the LLM
                return json.loads(data["response"])
            except Exception as e:
                logger.error(f"LLM Generation Error: {e}")
                return {"error": "Failed to generate explanation due to internal model error."}

explanation_generator = ExplanationGenerator()
