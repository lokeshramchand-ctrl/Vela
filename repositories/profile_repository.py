import logging
from datetime import UTC, datetime

from pymongo import ReturnDocument

from database.mongo import db
from models.schemas import MemoryState, MerchantProfile

logger = logging.getLogger(__name__)

class ProfileRepository:
    async def get_profile(self, canonical_name: str) -> MerchantProfile | None:
        data = await db.merchant_profiles.find_one({"canonical_name": canonical_name}, {"_id": 0})
        if data:
            return MerchantProfile(**data)
        return None

    async def increment_encounter(self, canonical_name: str, raw_text: str) -> tuple[MerchantProfile, bool]:
        """
        Atomically records one encounter of a merchant: increments frequency,
        bumps last_seen, adds the alias if new, and creates the profile on
        first sight - all in a single find_one_and_update(upsert=True).

        This replaces a prior read-modify-write (get_profile -> mutate in
        Python -> update_profile) that had two real races under concurrent
        traffic for the same merchant: a lost frequency increment (two
        requests both read frequency=N, both write N+1), and a check-then-
        insert race on a brand-new merchant where two concurrent first
        encounters could both see "no profile exists" and both insert,
        producing duplicate documents. A single atomic Mongo operation
        closes both, backed by the unique index on canonical_name
        (see database/mongo.py::ensure_indexes) which turns any remaining
        insert race into a retried upsert instead of a duplicate document.

        Returns (profile, is_new) where is_new is True only for the very
        first encounter (frequency == 1 immediately after $inc).
        """
        now = datetime.now(UTC)
        doc = await db.merchant_profiles.find_one_and_update(
            {"canonical_name": canonical_name},
            {
                "$inc": {"frequency": 1},
                "$set": {"last_seen": now},
                "$addToSet": {"aliases": raw_text},
                "$setOnInsert": {
                    "canonical_name": canonical_name,
                    "memory_state": MemoryState.EPHEMERAL.value,
                    "entity_type": "Unknown",
                    "first_seen": now,
                },
            },
            upsert=True,
            return_document=ReturnDocument.AFTER,
            projection={"_id": 0},
        )
        profile = MerchantProfile(**doc)
        is_new = profile.frequency == 1
        return profile, is_new

    async def set_memory_state(self, canonical_name: str, memory_state: MemoryState) -> None:
        """Minimal atomic update for a state-machine transition - doesn't
        require re-reading/re-writing the whole document like update_profile."""
        await db.merchant_profiles.update_one(
            {"canonical_name": canonical_name},
            {"$set": {"memory_state": memory_state.value}}
        )

    async def update_profile(self, profile: MerchantProfile):
        # Update everything except first_seen
        update_data = profile.model_dump(by_alias=True, exclude={"id", "first_seen", "canonical_name"})
        await db.merchant_profiles.update_one(
            {"canonical_name": profile.canonical_name},
            {"$set": update_data}
        )
        return profile

    async def get_stale_profiles(self, cutoff_date) -> list[MerchantProfile]:
        # Find profiles that haven't been seen since the cutoff date and aren't already archived
        cursor = db.merchant_profiles.find({
            "last_seen": {"$lt": cutoff_date},
            "memory_state": {"$ne": MemoryState.ARCHIVED.value}
        })
        return [MerchantProfile(**doc) async for doc in cursor]

profile_repo = ProfileRepository()
