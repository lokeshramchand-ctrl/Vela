import logging
from datetime import UTC, datetime, timedelta

from models.schemas import MemoryState
from repositories.profile_repository import profile_repo

logger = logging.getLogger(__name__)

class DecayEngine:
    def __init__(self):
        self.ARCHIVE_DAYS = 180

    async def run_archive_sweep(self):
        """
        Finds all profiles inactive for > 180 days and transitions them to ARCHIVED.
        """
        logger.info("Starting Memory Decay Sweep...")
        cutoff_date = datetime.now(UTC) - timedelta(days=self.ARCHIVE_DAYS)

        stale_profiles = await profile_repo.get_stale_profiles(cutoff_date)

        archived_count = 0
        for profile in stale_profiles:
            # Optional: You might decide PERMANENT memory never decays.
            # If so, add `if profile.memory_state == MemoryState.PERMANENT: continue`

            profile.memory_state = MemoryState.ARCHIVED
            await profile_repo.update_profile(profile)
            archived_count += 1

        logger.info(f"Sweep complete. {archived_count} profiles moved to ARCHIVED.")
        return archived_count

decay_engine = DecayEngine()
