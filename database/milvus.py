import logging
import time

from pymilvus import MilvusClient, MilvusException

from core.config import settings

logger = logging.getLogger(__name__)

class VectorDB:
    client: MilvusClient | None = None

    @classmethod
    def connect(cls, uri: str = None, retries: int = 5, delay: int = 3):
        # Use provided URI or fallback to settings
        uri = uri or settings.MILVUS_URI

        logger.info("Attempting to connect to Milvus at %s", uri)

        for attempt in range(1, retries + 1):
            try:
                cls.client = MilvusClient(uri=uri, secure=False)
                logger.info("Milvus connected successfully on attempt %d", attempt)

                # Confirm connectivity by listing collections
                collections = cls.client.list_collections()
                logger.debug("Milvus collections: %s", collections)
                return

            except MilvusException as e:
                logger.warning(
                    "Milvus not ready (attempt %d/%d): %s",
                    attempt, retries, str(e)
                )
                time.sleep(delay)

            except Exception:
                logger.exception("Unexpected error while connecting to Milvus")
                time.sleep(delay)

        logger.error("Failed to connect to Milvus after %d attempts", retries)
        cls.client = None

    @classmethod
    def disconnect(cls):
        if cls.client:
            logger.info("Disconnecting from Milvus...")
            try:
                cls.client.close()
                logger.info("Milvus disconnected successfully.")
            except Exception:
                logger.exception("Error while disconnecting Milvus")
            finally:
                cls.client = None

vector_db = VectorDB()
