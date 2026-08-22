from memory.state_machine import state_machine
from models.schemas import MemoryState, MerchantProfile
from repositories.profile_repository import profile_repo


class MemoryManager:
    async def process_encounter(self, canonical_name: str, raw_text: str) -> MerchantProfile:
        """
        Called every time a transaction is processed.
        Updates frequency, checks state transitions, and saves to DB.
        """
        # Atomically increments frequency / touches last_seen / adds the alias
        # / creates the profile on first sight - see
        # ProfileRepository.increment_encounter for why this must be one
        # atomic operation rather than a read-then-write.
        profile, is_new = await profile_repo.increment_encounter(canonical_name, raw_text)

        if is_new:
            return profile

        # Evaluate if it has earned a state promotion
        new_state = state_machine.evaluate_promotion(profile)

        # If it was archived but we just saw it again, wake it up as Temporary
        if profile.memory_state == MemoryState.ARCHIVED:
            new_state = MemoryState.TEMPORARY

        if new_state != profile.memory_state:
            await profile_repo.set_memory_state(canonical_name, new_state)
            profile.memory_state = new_state

        return profile

memory_manager = MemoryManager()
