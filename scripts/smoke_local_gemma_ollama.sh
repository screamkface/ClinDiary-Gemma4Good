#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/apps/backend"
RUNTIME_ENV="$ROOT_DIR/.runtime/ollama-local/gemma-local.env"

info() {
  printf '[ClinDiary][GemmaSmoke] %s\n' "$*" >&2
}

fail() {
  printf '[ClinDiary][GemmaSmoke] Errore: %s\n' "$*" >&2
  exit 1
}

if [[ ! -f "$RUNTIME_ENV" ]]; then
  fail "Env runtime non trovato: $RUNTIME_ENV. Esegui prima scripts/setup_local_gemma_ollama.sh"
fi

if [[ ! -x "$BACKEND_DIR/.venv/bin/python" ]]; then
  fail "Virtualenv backend mancante in $BACKEND_DIR/.venv"
fi

USER_LOCAL_LLM_MODEL_NAME="${LOCAL_LLM_MODEL_NAME:-}"
USER_LOCAL_EMBEDDING_MODEL_NAME="${LOCAL_EMBEDDING_MODEL_NAME:-}"
USER_LOCAL_LLM_BASE_URL="${LOCAL_LLM_BASE_URL:-}"
USER_LOCAL_LLM_BACKEND="${LOCAL_LLM_BACKEND:-}"
USER_LOCAL_EMBEDDING_DIMENSIONS="${LOCAL_EMBEDDING_DIMENSIONS:-}"
USER_AI_TIMEOUT_SECONDS="${AI_TIMEOUT_SECONDS:-}"

set -a
# shellcheck disable=SC1090
source "$RUNTIME_ENV"
set +a

if [[ -n "$USER_LOCAL_LLM_MODEL_NAME" ]]; then
  export LOCAL_LLM_MODEL_NAME="$USER_LOCAL_LLM_MODEL_NAME"
fi
if [[ -n "$USER_LOCAL_EMBEDDING_MODEL_NAME" ]]; then
  export LOCAL_EMBEDDING_MODEL_NAME="$USER_LOCAL_EMBEDDING_MODEL_NAME"
fi
if [[ -n "$USER_LOCAL_LLM_BASE_URL" ]]; then
  export LOCAL_LLM_BASE_URL="$USER_LOCAL_LLM_BASE_URL"
fi
if [[ -n "$USER_LOCAL_LLM_BACKEND" ]]; then
  export LOCAL_LLM_BACKEND="$USER_LOCAL_LLM_BACKEND"
fi
if [[ -n "$USER_LOCAL_EMBEDDING_DIMENSIONS" ]]; then
  export LOCAL_EMBEDDING_DIMENSIONS="$USER_LOCAL_EMBEDDING_DIMENSIONS"
fi
if [[ -n "$USER_AI_TIMEOUT_SECONDS" ]]; then
  export AI_TIMEOUT_SECONDS="$USER_AI_TIMEOUT_SECONDS"
fi

export PYTHONPATH="$BACKEND_DIR"

info "Smoke summary/report locale"
(
  cd "$BACKEND_DIR"
  .venv/bin/python -m app.ai_smoke --profile gemma_summary --require-external-provider
)

info "Smoke document answer locale"
(
  cd "$BACKEND_DIR"
  .venv/bin/python -m app.document_rag_smoke --mode answer --profile default --require-external-provider
)

info "Smoke embeddings locali"
(
  cd "$BACKEND_DIR"
  .venv/bin/python -m app.document_rag_smoke --profile embeddinggemma --require-external-provider
)

info "Smoke completati"
