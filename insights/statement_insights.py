import json
import logging
from typing import Any

import httpx

from core.ollama_client import LLM_MODEL, get_ollama_host
from models.schemas import InsightItem, StatementAnalytics

logger = logging.getLogger(__name__)


class StatementInsightGenerator:
    """Reuses the Ollama-calling convention already established in
    rag/generator.py (httpx + core.ollama_client.get_ollama_host() +
    format: "json" + a strict, grounding-only system prompt), but for a
    different task: summarizing a whole statement's already-computed
    analytics into natural-language observations. That's distinct from what
    rag/generator.py::ExplanationGenerator does (explaining one
    categorization decision from merchant behavior context) and isn't a fit
    to force onto that class.

    Grounded strictly in the analytics JSON already computed by
    analytics/statement_analytics.py - never given raw transaction rows or
    asked to invent a figure, so it can't report a number that doesn't
    reconcile with what's actually persisted.
    """

    system_prompt = """
You are the Vela Financial Insights Engine.
Your ONLY purpose is to turn a user's already-computed statement analytics into brief, natural-language financial observations.

RULES:
1. Use ONLY the numbers provided in the CONTEXT. Never invent a figure, merchant, or category that isn't present there.
2. Do not act like a chatbot. No greetings, no filler.
3. If the context has nothing insight-worthy for a category (e.g. no recurring payments detected), simply omit that kind of insight - do not fabricate one.
4. ALWAYS output a JSON array, where each element matches exactly:
{"type": "<short_snake_case_type>", "message": "<one concise sentence>", "severity": "INFO|POSITIVE|WARNING"}
5. Output ONLY the JSON array - no surrounding prose, no markdown fences.
"""

    async def generate(
        self,
        analytics: StatementAnalytics,
        previous_analytics: StatementAnalytics | None = None,
    ) -> list[InsightItem]:
        context: dict[str, Any] = {"current_statement": analytics.model_dump(exclude={"generated_at"})}
        if previous_analytics is not None:
            context["previous_statement"] = previous_analytics.model_dump(exclude={"generated_at"})

        prompt = f"CONTEXT:\n{json.dumps(context, default=str)}\n\nGenerate the insights JSON array now."

        payload = {
            "model": LLM_MODEL,
            "system": self.system_prompt,
            "prompt": prompt,
            "stream": False,
            "format": "json",
        }

        try:
            async with httpx.AsyncClient() as client:
                api_url = f"{get_ollama_host()}/api/generate"
                response = await client.post(api_url, json=payload, timeout=30.0)
                response.raise_for_status()
                data = response.json()
                raw_items = json.loads(data["response"])
        except Exception:
            # Insights are additive value on top of already-persisted
            # analytics - an Ollama/network hiccup here degrades to "no
            # insights this time", never a reason to fail the whole
            # statement-processing job (see statements/statement_service.py).
            logger.warning("Statement insight generation failed - continuing without insights.", exc_info=True)
            return []

        return self._to_insight_items(raw_items)

    @staticmethod
    def _to_insight_items(raw_items: Any) -> list[InsightItem]:
        if not isinstance(raw_items, list):
            return []

        items = []
        for raw in raw_items:
            try:
                items.append(InsightItem(**raw))
            except Exception:
                logger.warning("Discarding malformed insight item from LLM output: %r", raw)
        return items


statement_insight_generator = StatementInsightGenerator()
