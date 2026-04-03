BACKEND_VENV=apps/backend/.venv
BACKEND_PYTHON=$(BACKEND_VENV)/bin/python
BACKEND_PIP=$(BACKEND_VENV)/bin/pip
BACKEND_PYTEST=$(BACKEND_VENV)/bin/pytest

.PHONY: backend-install backend-test backend-run backend-seed worker-run beat-run mobile-get mobile-analyze mobile-test stack-up stack-down android-run

backend-install:
	python3 -m venv $(BACKEND_VENV)
	$(BACKEND_PIP) install -e apps/backend[dev]

backend-test:
	$(BACKEND_PYTEST) apps/backend/tests

backend-run:
	PYTHONPATH=apps/backend $(BACKEND_VENV)/bin/uvicorn app.main:app --app-dir apps/backend --reload

backend-seed:
	PYTHONPATH=apps/backend $(BACKEND_VENV)/bin/clindiary-seed

worker-run:
	PYTHONPATH=apps/backend $(BACKEND_VENV)/bin/celery -A app.workers.celery_app.celery_app worker --loglevel=info

beat-run:
	PYTHONPATH=apps/backend $(BACKEND_VENV)/bin/celery -A app.workers.celery_app.celery_app beat --loglevel=info

mobile-get:
	cd apps/mobile && flutter pub get

mobile-analyze:
	cd apps/mobile && flutter analyze

mobile-test:
	cd apps/mobile && flutter test

stack-up:
	docker compose -f infra/compose/docker-compose.yml up -d

stack-down:
	docker compose -f infra/compose/docker-compose.yml down

android-run:
	bash scripts/run_android_app.sh
