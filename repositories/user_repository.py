import logging
from datetime import UTC, datetime

from bson import ObjectId
from bson.errors import InvalidId
from pymongo import ReturnDocument

from database.mongo import db
from models.schemas import User

logger = logging.getLogger(__name__)

class UserRepository:
    async def get_by_email(self, email: str) -> User | None:
        doc = await db.users.find_one({"email": email})
        if not doc:
            return None
        doc["_id"] = str(doc["_id"])
        return User(**doc)

    async def get_by_id(self, user_id: str) -> User | None:
        try:
            oid = ObjectId(user_id)
        except (InvalidId, TypeError):
            return None
        doc = await db.users.find_one({"_id": oid})
        if not doc:
            return None
        doc["_id"] = str(doc["_id"])
        return User(**doc)

    async def create_user(self, email: str, hashed_password: str) -> User:
        """Raises pymongo.errors.DuplicateKeyError if email is already taken -
        the unique index on `users.email` (see database/mongo.py::ensure_indexes)
        is the real race-safe guarantee; callers should still pre-check with
        get_by_email() for the fast, non-racing common case."""
        now = datetime.now(UTC)
        doc = {
            "email": email,
            "hashed_password": hashed_password,
            "is_active": True,
            "created_at": now,
            "updated_at": now,
        }
        result = await db.users.insert_one(doc)
        doc["_id"] = str(result.inserted_id)
        return User(**doc)

    async def update_full_name(self, user_id: str, full_name: str) -> User | None:
        doc = await db.users.find_one_and_update(
            {"_id": ObjectId(user_id)},
            {"$set": {"full_name": full_name, "updated_at": datetime.now(UTC)}},
            return_document=ReturnDocument.AFTER,
        )
        if not doc:
            return None
        doc["_id"] = str(doc["_id"])
        return User(**doc)

user_repo = UserRepository()
