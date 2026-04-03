import os
from collections.abc import Generator
from pathlib import Path
import tempfile

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker


_test_root = Path(tempfile.mkdtemp(prefix="clindiary-tests-"))
_db_path = _test_root / "test.sqlite"
_storage_path = _test_root / "storage"

os.environ["DATABASE_URL"] = f"sqlite+pysqlite:///{_db_path}"
os.environ["JWT_SECRET_KEY"] = "test-secret-key-that-is-long-enough"
os.environ["DEBUG"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["STORAGE_BACKEND"] = "local"
os.environ["LOCAL_STORAGE_PATH"] = str(_storage_path)
os.environ["CELERY_TASK_ALWAYS_EAGER"] = "true"
os.environ["CELERY_TASK_EAGER_PROPAGATES"] = "true"
os.environ["AI_PROVIDER"] = "rule_based"
os.environ["AI_MODEL_NAME"] = "clindiary-safe-summary"
os.environ["AI_BASE_URL"] = ""
os.environ["AI_API_KEY"] = ""
os.environ["GEMINI_API_KEY"] = ""
os.environ["GOOGLE_OAUTH_CLIENT_ID"] = "test-google-client-id.apps.googleusercontent.com"

from app.core.config import get_settings  # noqa: E402


get_settings.cache_clear()

from app.core.database import get_db  # noqa: E402
from app.main import create_app  # noqa: E402
from app.models import Base  # noqa: E402


engine = create_engine(
    f"sqlite+pysqlite:///{_db_path}",
    connect_args={"check_same_thread": False},
    future=True,
)
TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, expire_on_commit=False)


@pytest.fixture()
def db_session() -> Generator[Session, None, None]:
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture()
def client(db_session: Session) -> Generator[TestClient, None, None]:
    app = create_app()

    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture()
def free_auth_headers(client: TestClient) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={"email": "patient@example.com", "password": "StrongPass123!"},
    )
    access_token = response.json()["access_token"]
    client.post(
        "/api/v1/profile/onboarding/complete",
        headers={"Authorization": f"Bearer {access_token}"},
        json={
            "health_data_consent": True,
            "ai_external_consent": False,
            "first_name": "Anna",
            "last_name": "Bianchi",
            "birth_date": "1992-04-10",
            "biological_sex": "female",
            "smoker": False,
        },
    )
    return {"Authorization": f"Bearer {access_token}"}


@pytest.fixture()
def auth_headers(client: TestClient, free_auth_headers: dict[str, str]) -> dict[str, str]:
    activation_response = client.post(
        "/api/v1/billing/dev/activate",
        headers=free_auth_headers,
        json={"plan_code": "ai_plus_yearly"},
    )
    assert activation_response.status_code == 200
    return free_auth_headers
