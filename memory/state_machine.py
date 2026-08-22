import logging

from models.schemas import MemoryState, MerchantProfile

logger = logging.getLogger(__name__)

class StateMachine:
    def __init__(self):
        # Thresholds configured exactly to your Phase 4 spec
        self.TEMPORARY_THRESHOLD = 3
        self.PERMANENT_THRESHOLD = 10

    def evaluate_promotion(self, profile: MerchantProfile) -> MemoryState:
        """Determines if a profile has earned a higher memory state based on frequency."""
        current_state = profile.memory_state

        # Once permanent or archived, frequency alone doesn't change it via promotion
        if current_state in [MemoryState.PERMANENT, MemoryState.ARCHIVED]:
            return current_state

        if profile.frequency >= self.PERMANENT_THRESHOLD:
            logger.info(f"[{profile.canonical_name}] Promoting to PERMANENT.")
            return MemoryState.PERMANENT

        if profile.frequency >= self.TEMPORARY_THRESHOLD:
            if current_state == MemoryState.EPHEMERAL:
                logger.info(f"[{profile.canonical_name}] Promoting to TEMPORARY.")
            return MemoryState.TEMPORARY

        return MemoryState.EPHEMERAL

state_machine = StateMachine()
