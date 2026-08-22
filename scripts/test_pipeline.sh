#!/bin/bash

BASE_URL="http://localhost:8080"

# Default fallback key (matches the hardcoded fallback in core/security.py)
API_KEY="Vela_test_key_123"

# Safely attempt to load Vela_API_KEY from .env if it exists in the current directory
if [ -f ".env" ]; then
    PARSED_KEY=$(grep -v '^#' .env | grep -E '^Vela_API_KEY=' | cut -d '=' -f2 | tr -d '"' | tr -d "'")
    if [ ! -z "$PARSED_KEY" ]; then
        API_KEY="$PARSED_KEY"
        echo "🔒 Loaded API Key from .env file"
    fi
fi

echo -e "\n============================================="
echo "  Vela TRANSACTION ENGINE - E2E TEST "
echo -e "=============================================\n"

echo -e "--- PHASE 3: MERCHANT RESOLUTION ---"
echo "Sending noisy UPI string: 'UPI/CR/3152671239/BUNDL TECHNOLOGIES/HDFC'"
curl -s -X POST "$BASE_URL/v1/resolve" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -H "X-Vela-API-Key: $API_KEY" \
  -d "{\"text\": \"UPI/CR/3152671239/BUNDL TECHNOLOGIES/HDFC\"}"
echo -e "\n\n"
sleep 1

echo -e "--- PHASE 4: MEMORY ENGINE (STATE PROMOTION) ---"
echo "Simulating 3 transactions for a new entity 'Zomato' to trigger TEMPORARY state."
for i in {1..3}
do
   echo "Encounter $i:"
   curl -s -X POST "$BASE_URL/memory/update" \
     -H "accept: application/json" \
     -H "Content-Type: application/json" \
     -H "X-Vela-API-Key: $API_KEY" \
     -d "{\"canonical_name\": \"Zomato\", \"raw_text\": \"paid to zomato media pvt\"}"
   echo -e "\n"
done
echo -e "\n"
sleep 1

echo -e "--- PHASE 5: CONFIDENCE WALL ---"
echo "Evaluating a low-confidence ML prediction (Confidence: 0.40). Should route to UNKNOWN."
curl -s -X POST "$BASE_URL/v1/confidence/evaluate" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -H "X-Vela-API-Key: $API_KEY" \
  -d "{\"predicted_category\": \"Travel\", \"raw_confidence\": 0.40}"
echo -e "\n\n"
sleep 1

echo -e "--- PREPARING MOCK DATA FOR ANALYTICS ---"
# Run the python seeder script from the backend directory
python scripts/mock_seeder.py
echo -e "\n"
sleep 1

echo -e "--- PHASE 13: ANALYTICS ENGINE ---"
echo "1. Fetching top merchants (Ranked by visit frequency):"
curl -s -X GET "$BASE_URL/v1/analytics/patterns/merchants?limit=3" \
  -H "accept: application/json" \
  -H "X-Vela-API-Key: $API_KEY"
echo -e "\n\n"

echo "2. Fetching category breakdown (Last 30 days):"
curl -s -X GET "$BASE_URL/v1/analytics/patterns/categories?days=30" \
  -H "accept: application/json" \
  -H "X-Vela-API-Key: $API_KEY"
echo -e "\n\n"

echo -e "--- CLEANING UP MOCK DATA ---"
python scripts/mock_seeder.py cleanup
echo -e "\n"

echo -e "============================================="
echo "  TEST COMPLETE"
echo -e "=============================================\n"