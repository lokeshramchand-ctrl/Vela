from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    MONGODB_URI: str
    MONGODB_DB_NAME: str = "Vela"
    MILVUS_URI: str
    OLLAMA_URI: str | None = None  # optional single host
    OLLAMA_HOSTS: str | None = None  # comma-separated list
    EMBED_MODEL: str
    LLM_MODEL: str
    Vela_API_KEY: str

    # JWT user authentication (core/jwt_auth.py, routers/auth.py). Distinct
    # from Vela_API_KEY above: the API key authenticates the calling
    # application, JWT_SECRET_KEY signs per-user access tokens issued after
    # login - see docs/01-architecture.md Â§1.8.
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Operational settings (all have safe production-appropriate defaults)
    ENVIRONMENT: str = "production"  # "production" | "development"
    LOG_LEVEL: str = "INFO"  # DEBUG is opt-in, never the default - DEBUG logs full DB command payloads
    # Raised from the original 1 MB (fine when every request was a JSON body)
    # to accommodate multipart PDF statement uploads - see POST /statements/upload.
    # MAX_STATEMENT_PDF_BYTES below is the tighter, upload-specific ceiling
    # checked in routers/statements.py for a clearer, PDF-specific error
    # message; this middleware-level limit is the outer backstop for every
    # request body regardless of route.
    MAX_REQUEST_BODY_BYTES: int = 15_000_000  # 15 MB
    MAX_STATEMENT_PDF_BYTES: int = 10_000_000  # 10 MB
    MONGODB_SERVER_SELECTION_TIMEOUT_MS: int = 5000
    MONGODB_CONNECT_TIMEOUT_MS: int = 5000

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    @field_validator("JWT_SECRET_KEY")
    @classmethod
    def _require_strong_jwt_secret(cls, v: str) -> str:
        # Fails app startup immediately rather than letting a short/weak
        # secret (e.g. a copy-pasted placeholder) silently sign real tokens -
        # same "fail fast on a bad mandatory secret" posture as every other
        # required setting above, extended to also cover *weak* values since
        # a present-but-trivial signing key is just as dangerous as a missing
        # one. 32 bytes matches common guidance for HS256 signing keys.
        if len(v) < 32:
            raise ValueError(
                "JWT_SECRET_KEY must be at least 32 characters long "
                "(generate one with: openssl rand -hex 32)"
            )
        return v

    @property
    def ollama_hosts_list(self) -> list[str]:
        """Convert comma-separated hosts into a list."""
        if self.OLLAMA_HOSTS:
            return [h.strip() for h in self.OLLAMA_HOSTS.split(",")]
        return []

settings = Settings()

