import asyncio
import random
import sys
from datetime import UTC, datetime, timedelta

from motor.motor_asyncio import AsyncIOMotorClient

# Connect directly to the local MongoDB instance
MONGO_URI = "mongodb://localhost:27017"
DB_NAME = "velar"

async def seed():
    client = AsyncIOMotorClient(MONGO_URI)
    db = client[DB_NAME]

    now = datetime.now(UTC)

    # Realistic merchants and categories
    merchant_pool = [
        ("Swiggy", "Food"), ("Zomato", "Food"), ("Starbucks", "Food"),
        ("Uber", "Travel"), ("Ola", "Travel"), ("MakeMyTrip", "Travel"),
        ("Netflix", "Subscription"), ("Amazon Prime", "Subscription"),
        ("Jio", "Utility"), ("Airtel", "Utility")
    ]

    mock_transactions = []

    # Generate 100 mock transactions spread across the last 60 days
    for _ in range(100):
        merchant, category = random.choice(merchant_pool)
        amount = round(random.uniform(50.0, 2500.0), 2)
        days_ago = random.randint(0, 60)

        mock_transactions.append({
            "user_id": "user_123", # Local mock id - not tied to a real registered account
            "merchant": merchant,
            "category": category,
            "amount": amount,
            "timestamp": now - timedelta(days=days_ago),
            "is_mock": True # Crucial flag so we only delete fake data later
        })

    await db.transactions.insert_many(mock_transactions)
    print(f"✅ Successfully injected {len(mock_transactions)} mock transactions into MongoDB.")
    client.close()

async def cleanup():
    client = AsyncIOMotorClient(MONGO_URI)
    db = client[DB_NAME]

    # Only delete transactions flagged as mock for our test user
    result = await db.transactions.delete_many({"user_id": "user_123", "is_mock": True})
    print(f"🧹 Cleaned up {result.deleted_count} mock transactions from MongoDB.")
    client.close()

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "cleanup":
        asyncio.run(cleanup())
    else:
        asyncio.run(seed())
