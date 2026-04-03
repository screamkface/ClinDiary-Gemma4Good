#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="$ROOT_DIR/.runtime/ollama-local"
INSTALL_DIR="$RUNTIME_DIR/runtime"
MODELS_DIR="$RUNTIME_DIR/models"
LOG_DIR="$RUNTIME_DIR/logs"
PID_FILE="$RUNTIME_DIR/serve.pid"
HOST="${OLLAMA_LOCAL_HOST:-127.0.0.1}"
PORT="${OLLAMA_LOCAL_PORT:-11435}"
GEN_MODEL="${LOCAL_GEMMA_MODEL:-gemma4:e2b}"
EMBED_MODEL="${LOCAL_EMBEDDING_MODEL:-embeddinggemma}"
KEEP_SERVER=false
SKIP_INSTALL=false
SKIP_PULL=false

usage() {
  cat <<'EOF'
Uso:
  bash scripts/setup_local_gemma_ollama.sh [opzioni]

Opzioni:
  --keep-server   Lascia il server locale attivo dopo il bootstrap.
  --skip-install  Salta l'installazione user-space di Ollama.
  --skip-pull     Salta il pull dei modelli locali.
  --help          Mostra questo aiuto.

Env utili:
  OLLAMA_LOCAL_HOST=127.0.0.1
  OLLAMA_LOCAL_PORT=11435
  LOCAL_GEMMA_MODEL=gemma4:e2b
  LOCAL_EMBEDDING_MODEL=embeddinggemma
EOF
}

info() {
  printf '[ClinDiary][GemmaLocal] %s\n' "$*" >&2
}

fail() {
  printf '[ClinDiary][GemmaLocal] Errore: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Comando richiesto non trovato: $1"
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --keep-server)
        KEEP_SERVER=true
        ;;
      --skip-install)
        SKIP_INSTALL=true
        ;;
      --skip-pull)
        SKIP_PULL=true
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        fail "Opzione non riconosciuta: $1"
        ;;
    esac
    shift
  done
}

ollama_bin() {
  if [[ -x "$INSTALL_DIR/ollama" ]]; then
    printf '%s\n' "$INSTALL_DIR/ollama"
    return 0
  fi
  if [[ -x "$INSTALL_DIR/bin/ollama" ]]; then
    printf '%s\n' "$INSTALL_DIR/bin/ollama"
    return 0
  fi
  return 1
}

install_local_ollama() {
  local tmp_dir archive_url archive_path staged_dir version_output

  require_command curl
  require_command tar
  require_command zstd

  mkdir -p "$RUNTIME_DIR"
  tmp_dir="$(mktemp -d)"
  archive_path="$tmp_dir/ollama-linux-amd64.tar.zst"
  staged_dir="$tmp_dir/staged"
  mkdir -p "$staged_dir"
  archive_url="https://ollama.com/download/ollama-linux-amd64.tar.zst"

  info "Scarico Ollama user-space ufficiale..."
  curl --fail --show-error --location --progress-bar \
    -o "$archive_path" \
    "$archive_url"

  info "Estraggo Ollama in $INSTALL_DIR ..."
  rm -rf "$INSTALL_DIR.tmp"
  mkdir -p "$INSTALL_DIR.tmp"
  zstd -dc "$archive_path" | tar -xf - -C "$INSTALL_DIR.tmp"

  if [[ ! -x "$INSTALL_DIR.tmp/ollama" && ! -x "$INSTALL_DIR.tmp/bin/ollama" ]]; then
    fail "Impossibile trovare il binario Ollama nell'archivio estratto."
  fi

  rm -rf "$INSTALL_DIR"
  mv "$INSTALL_DIR.tmp" "$INSTALL_DIR"
  rm -rf "$tmp_dir"

  version_output="$("$(ollama_bin)" --version 2>/dev/null || true)"
  info "Ollama locale pronto: ${version_output:-versione non disponibile}"
}

server_ready() {
  curl -fsS "http://${HOST}:${PORT}/api/version" >/dev/null 2>&1
}

ensure_server() {
  local bin log_file
  bin="$(ollama_bin)" || fail "Binario Ollama locale non trovato. Esegui senza --skip-install."

  mkdir -p "$MODELS_DIR" "$LOG_DIR"
  log_file="$LOG_DIR/serve.log"

  if server_ready; then
    info "Server Ollama locale gia attivo su http://${HOST}:${PORT}"
    return 0
  fi

  info "Avvio Ollama locale su http://${HOST}:${PORT}"
  if command -v setsid >/dev/null 2>&1; then
    setsid env OLLAMA_HOST="${HOST}:${PORT}" OLLAMA_MODELS="$MODELS_DIR" \
      "$bin" serve >>"$log_file" 2>&1 < /dev/null &
  else
    nohup env OLLAMA_HOST="${HOST}:${PORT}" OLLAMA_MODELS="$MODELS_DIR" \
      "$bin" serve >>"$log_file" 2>&1 < /dev/null &
  fi
  echo $! >"$PID_FILE"

  for _ in $(seq 1 60); do
    if server_ready; then
      info "Server Ollama locale pronto"
      return 0
    fi
    sleep 1
  done

  fail "Ollama locale non e diventato raggiungibile. Controlla $log_file"
}

pull_models() {
  local bin
  bin="$(ollama_bin)" || fail "Binario Ollama locale non trovato."

  info "Pull modello generativo: $GEN_MODEL"
  OLLAMA_HOST="${HOST}:${PORT}" OLLAMA_MODELS="$MODELS_DIR" \
    "$bin" pull "$GEN_MODEL"

  info "Pull modello embeddings: $EMBED_MODEL"
  OLLAMA_HOST="${HOST}:${PORT}" OLLAMA_MODELS="$MODELS_DIR" \
    "$bin" pull "$EMBED_MODEL"
}

write_env_hint() {
  local env_file
  env_file="$RUNTIME_DIR/gemma-local.env"
  cat >"$env_file" <<EOF
SUMMARY_AI_PROVIDER=gemma
SUMMARY_AI_RUNTIME_MODE=local
DOCUMENT_ANSWER_PROVIDER=gemma
DOCUMENT_ANSWER_RUNTIME_MODE=local
DOCUMENT_EMBEDDING_PROVIDER=gemma
DOCUMENT_EMBEDDING_RUNTIME_MODE=local
DOCUMENT_RERANKER_PROVIDER=rule_based
LOCAL_LLM_BACKEND=ollama
LOCAL_LLM_BASE_URL=http://${HOST}:${PORT}
LOCAL_LLM_MODEL_NAME=${GEN_MODEL}
LOCAL_EMBEDDING_MODEL_NAME=${EMBED_MODEL}
LOCAL_EMBEDDING_DIMENSIONS=768
LOCAL_MAX_CONTEXT_TOKENS=8192
AI_TIMEOUT_SECONDS=300
EOF
  info "Hint env scritto in $env_file"
}

cleanup() {
  if [[ "$KEEP_SERVER" == "true" ]]; then
    return 0
  fi
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      info "Arresto Ollama locale avviato da questo script"
      kill "$pid" >/dev/null 2>&1 || true
    fi
    rm -f "$PID_FILE"
  fi
}

main() {
  trap cleanup EXIT
  parse_args "$@"

  if [[ "$SKIP_INSTALL" == "false" ]]; then
    install_local_ollama
  fi

  ensure_server

  if [[ "$SKIP_PULL" == "false" ]]; then
    pull_models
  fi

  write_env_hint
  info "Setup completato"
}

main "$@"
