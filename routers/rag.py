from fastapi import APIRouter, Request
from pydantic import BaseModel, Field

from core.rate_limiter import limiter
from rag.context_builder import context_builder
from rag.generator import explanation_generator
from rag.retriever import context_retriever

router = APIRouter(prefix="/v1", tags=["Explainability"])

class ExplainRequest(BaseModel):
    transaction_text: str = Field(..., min_length=1, max_length=2000)
    target_question: str = Field(
        default="Why was this transaction categorized this way?", max_length=500
    )

@router.post("/explain")
@limiter.limit("20/minute")
async def explain_transaction(request: Request, payload: ExplainRequest):
    """
    RAG Pipeline: Retrieves behavioral vectors and generates a strict, grounded explanation.
    Rate-limited tighter than the default (20/minute) since each call triggers an
    embedding call plus an LLM generation call against Ollama - both expensive
    relative to the rest of the API, and a plausible resource-exhaustion vector.
    """
    # 1. Retrieve
    raw_context = await context_retriever.fetch_grounded_context(payload.transaction_text)

    # 2. Build
    formatted_context = context_builder.build_prompt_string(raw_context)

    # 3. Generate
    explanation = await explanation_generator.generate_explanation(
        query=payload.target_question,
        context_string=formatted_context
    )

    return {
        "query": payload.transaction_text,
        "retrieved_documents": len(raw_context),
        "result": explanation
    }
