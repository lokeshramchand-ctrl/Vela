import logging

from pymilvus import DataType

from database.milvus import vector_db

logger = logging.getLogger(__name__)

VECTOR_DIM = 768

class VectorStoreManager:
    """
    Thin wrapper around the single shared Milvus client owned by
    `database.milvus.vector_db` (connected/disconnected via the app lifespan).
    This class intentionally does not open its own connection so importing it
    never performs network I/O and never creates a second, independently
    configured MilvusClient.
    """
    behavior_col_name = "behavior_vectors"

    @property
    def client(self):
        return vector_db.client

    def ensure_collections(self):
        """Creates collection and HNSW index if not exists. Call once Milvus is connected."""
        client = self.client
        if client is None:
            logger.warning("Milvus client not connected; skipping collection setup.")
            return

        if not client.has_collection(self.behavior_col_name):
            schema = client.create_schema(auto_id=False, enable_dynamic_field=False)
            schema.add_field("id", DataType.VARCHAR, is_primary=True, max_length=255)
            schema.add_field("merchant_name", DataType.VARCHAR, max_length=255)
            schema.add_field("embedding", DataType.FLOAT_VECTOR, dim=VECTOR_DIM)

            index_params = client.prepare_index_params()
            index_params.add_index(
                field_name="embedding",
                index_type="HNSW",
                metric_type="COSINE",
                params={"M": 8, "efConstruction": 200},
            )

            client.create_collection(self.behavior_col_name, schema=schema, index_params=index_params)
            logger.info("Created Milvus collection: %s", self.behavior_col_name)

        # Load collection into memory
        client.load_collection(self.behavior_col_name)

    def insert_behavior_vector(self, pattern_id: str, merchant_name: str, vector: list[float]):
        """Insert or overwrite a vector in Milvus."""
        client = self.client
        if client is None:
            raise RuntimeError("Milvus is not connected; cannot insert vector.")
        data = [
            {"id": pattern_id, "merchant_name": merchant_name, "embedding": vector}
        ]
        client.upsert(self.behavior_col_name, data)
        logger.info("Inserted vector for entity: %s", merchant_name)

vector_store = VectorStoreManager()
