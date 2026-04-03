from functools import lru_cache

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "ClinDiary API"
    environment: str = "development"
    debug: bool = True
    api_v1_prefix: str = "/api/v1"
    database_url: str = "postgresql+psycopg://clindiary:clindiary@localhost:5432/clindiary"
    redis_url: str = "redis://localhost:6379/0"
    jwt_secret_key: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_ttl_minutes: int = 15
    refresh_token_ttl_days: int = 30
    password_reset_ttl_minutes: int = 30
    allowed_origins: str = Field(
        default="http://localhost:3000,http://localhost:8080,http://localhost:5000"
    )
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket: str = "clindiary"
    minio_secure: bool = False
    storage_backend: str = "minio"
    local_storage_path: str = "./.storage"
    document_max_size_mb: int = 20
    viewer_url_ttl_minutes: int = 15
    document_magic_bytes_validation: bool = True
    document_scan_provider: str = "none"
    document_scan_webhook_url: str | None = None
    document_scan_fail_closed: bool = False
    ai_provider: str = "rule_based"
    ai_model_name: str = "clindiary-safe-summary"
    ai_base_url: str | None = None
    ai_api_key: str | None = None
    regolo_api_key: str | None = None
    regolo_base_url: str = "https://api.regolo.ai/v1"
    regolo_model_name: str = "minimax-m2.5"
    document_answer_model_name: str = "qwen3-8b"
    document_embedding_model_name: str = "qwen3-embedding-8b"
    document_embedding_dimensions: int | None = 1024
    document_reranker_model_name: str = "qwen3-reranker-4b"
    document_chunk_size_chars: int = 1200
    document_chunk_overlap_chars: int = 200
    document_candidate_limit: int = 48
    document_rerank_top_n: int = 10
    document_answer_top_n: int = 6
    withings_client_id: str | None = None
    withings_client_secret: str | None = None
    withings_redirect_uri: str | None = None
    ihealth_client_id: str | None = None
    ihealth_client_secret: str | None = None
    ihealth_redirect_uri: str | None = None
    dexcom_client_id: str | None = None
    dexcom_client_secret: str | None = None
    dexcom_redirect_uri: str | None = None
    gemini_api_key: str | None = None
    gemini_thinking_budget: int | None = 0
    ai_timeout_seconds: int = 60
    ai_temperature: float = 0.1
    ai_max_output_tokens: int = 2048
    google_oauth_client_id: str | None = None
    ocr_provider: str = "paddleocr"
    ocr_fallback_provider: str | None = "tesseract"
    ocr_language: str = "it"
    ocr_use_gpu: bool = False
    ocr_max_pages: int = 8
    ocr_retry_attempts: int = 2
    ocr_tesseract_command: str = "tesseract"
    ocr_fallback_to_pending: bool = True
    celery_task_always_eager: bool = False
    celery_task_eager_propagates: bool = False
    notification_sync_interval_minutes: int = 15
    retention_ai_summaries_days: int = 0
    retention_audit_logs_days: int = 365
    retention_refresh_tokens_days: int = 30
    retention_password_reset_tokens_days: int = 7
    password_reset_preview_enabled: bool = True
    rate_limit_enabled: bool = True
    rate_limit_backend: str = "auto"
    rate_limit_auth_requests: int = 30
    rate_limit_window_seconds: int = 60
    rate_limit_prefix: str = "clindiary-rate-limit"
    notification_push_provider: str = "log_only"
    notification_push_webhook_url: str | None = None
    notification_fcm_project_id: str | None = None
    notification_fcm_access_token: str | None = None
    notification_fcm_service_account_file: str | None = None
    notification_fcm_service_account_json: str | None = None
    notification_apns_key_id: str | None = None
    notification_apns_team_id: str | None = None
    notification_apns_bundle_id: str | None = None
    notification_apns_private_key: str | None = None
    notification_apns_use_sandbox: bool = True
    notification_email_provider: str = "log_only"
    notification_email_from: str = "no-reply@clindiary.local"
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_username: str | None = None
    smtp_password: str | None = None
    smtp_use_tls: bool = True

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    @property
    def allowed_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.allowed_origins.split(",") if origin.strip()]

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @field_validator("environment", mode="before")
    @classmethod
    def _normalize_environment(cls, value):
        if value is None:
            return "development"
        normalized = str(value).strip().lower()
        aliases = {
            "prod": "production",
            "release": "production",
            "dev": "development",
        }
        return aliases.get(normalized, normalized or "development")

    @field_validator("debug", mode="before")
    @classmethod
    def _coerce_debug_flag(cls, value):
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"release", "prod", "production"}:
                return False
            if normalized in {"development", "dev"}:
                return True
            if normalized in {"1", "true", "yes", "on"}:
                return True
            if normalized in {"0", "false", "no", "off"}:
                return False
        return value

    @model_validator(mode="after")
    def _validate_production_settings(self):
        if not self.is_production:
            return self

        if self.debug:
            raise ValueError("DEBUG must be false when ENVIRONMENT=production")
        if self.jwt_secret_key == "change-me-in-production" or len(self.jwt_secret_key.strip()) < 32:
            raise ValueError("JWT_SECRET_KEY must be set to a strong secret in production")
        if not self.allowed_origins_list:
            raise ValueError("ALLOWED_ORIGINS must be configured in production")

        localhost_origins = [
            origin
            for origin in self.allowed_origins_list
            if "localhost" in origin.lower() or "127.0.0.1" in origin.lower()
        ]
        if localhost_origins:
            raise ValueError("ALLOWED_ORIGINS cannot include localhost origins in production")

        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
