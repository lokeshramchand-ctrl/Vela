from typing import Any


class ContextBuilder:
    @staticmethod
    def build_prompt_string(context_data: list[dict[str, Any]]) -> str:
        """
        Transforms raw database payloads into a strictly formatted string
        to prevent the LLM from hallucinating outside the bounds of the data.
        """
        if not context_data:
            return "NO_CONTEXT_AVAILABLE"

        prompt_blocks = []
        for idx, data in enumerate(context_data, 1):
            name = data.get("merchant_name", "Unknown")
            profile = data.get("profile", {})
            behavior = data.get("behavior", {})
            feedback = data.get("recent_feedback", [])

            block = f"""
<MERCHANT_DATA ID="{idx}">
    <NAME>{name}</NAME>
    <MEMORY_STATE>{profile.get('memory_state', 'UNKNOWN')}</MEMORY_STATE>
    <FREQUENCY>{profile.get('frequency', 0)} total transactions</FREQUENCY>
    <BEHAVIOR_SIGNATURE>
        Average Amount: {behavior.get('avg_amount', 'N/A')}
        Periodicity Score: {behavior.get('periodicity_score', 'N/A')} (1.0 = Highly predictable)
        Preferred Hour: {behavior.get('preferred_hour', 'N/A')}:00
    </BEHAVIOR_SIGNATURE>
    <HUMAN_CORRECTIONS>
        {len(feedback)} recent manual corrections found.
    </HUMAN_CORRECTIONS>
</MERCHANT_DATA>
"""
            prompt_blocks.append(block)

        return "\n".join(prompt_blocks)

context_builder = ContextBuilder()
