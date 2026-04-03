from app.core.config import get_settings
from app.main import create_app


def test_create_app_exposes_docs_in_development(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setenv("DEBUG", "true")
    get_settings.cache_clear()

    try:
        app = create_app()

        assert app.docs_url == "/docs"
        assert app.redoc_url == "/redoc"
        assert app.openapi_url == "/openapi.json"
    finally:
        get_settings.cache_clear()


def test_create_app_hides_docs_in_production(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("DEBUG", "false")
    monkeypatch.setenv("JWT_SECRET_KEY", "x" * 48)
    monkeypatch.setenv("ALLOWED_ORIGINS", "https://app.example.com")
    get_settings.cache_clear()

    try:
        app = create_app()

        assert app.docs_url is None
        assert app.redoc_url is None
        assert app.openapi_url is None
    finally:
        get_settings.cache_clear()
