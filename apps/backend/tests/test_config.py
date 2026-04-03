from app.core.config import Settings


def test_settings_debug_accepts_release_alias():
    settings = Settings(debug="release")

    assert settings.debug is False


def test_settings_debug_accepts_development_alias():
    settings = Settings(debug="development")

    assert settings.debug is True


def test_settings_reject_insecure_production_defaults():
    try:
        Settings(
            environment="production",
            debug=False,
            jwt_secret_key="change-me-in-production",
            allowed_origins="https://app.example.com",
        )
    except ValueError as exc:
        assert "JWT_SECRET_KEY" in str(exc)
    else:
        raise AssertionError("Expected insecure production defaults to be rejected")


def test_settings_reject_localhost_origins_in_production():
    try:
        Settings(
            environment="production",
            debug=False,
            jwt_secret_key="x" * 48,
            allowed_origins="http://localhost:3000,https://app.example.com",
        )
    except ValueError as exc:
        assert "localhost" in str(exc)
    else:
        raise AssertionError("Expected localhost origins to be rejected in production")


def test_settings_accept_safe_production_configuration():
    settings = Settings(
        environment="production",
        debug=False,
        jwt_secret_key="x" * 48,
        allowed_origins="https://app.example.com,https://admin.example.com",
    )

    assert settings.is_production is True
    assert settings.allowed_origins_list == [
        "https://app.example.com",
        "https://admin.example.com",
    ]


def test_settings_normalize_ai_runtime_aliases():
    settings = Settings(
        document_ai_runtime_mode="local",
        embedding_runtime_mode="local",
    )

    assert settings.document_answer_runtime_mode == "local"
    assert settings.document_embedding_runtime_mode == "local"


def test_settings_normalize_local_backend_aliases():
    settings = Settings(local_llm_backend="llama.cpp")

    assert settings.local_llm_backend == "llama_cpp"
