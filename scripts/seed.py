# backend/scripts/seed_merchants.py
import asyncio

from database.mongo import db


async def seed():
    await db.connect()

    # Vela Phase 3 Seed Data
    merchants = [
        {
            "canonical_name": "Swiggy",
            "aliases": ["BUNDL TECHNOLOGIES", "SWIGGY", "BUNDL", "SWIGGY BENGALURU"]
        },
        {
            "canonical_name": "Zomato",
            "aliases": ["ZOMATO MEDIA", "ZOMATO", "ZOMATO LTD"]
        },
        {
            "canonical_name": "Netflix",
            "aliases": ["NETFLIX ENTERTAINMENT", "NFLX", "NETFLIX"]
        }
    ]

    # Clear existing and insert
    await db.merchants.delete_many({})
    await db.merchants.insert_many(merchants)
    print("Seeded canonical merchants successfully.")

    await db.disconnect()

if __name__ == "__main__":
    asyncio.run(seed())
