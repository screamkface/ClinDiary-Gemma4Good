#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/apps/backend"
MOBILE_DIR="$ROOT_DIR/apps/mobile"
BACKEND_VENV="$BACKEND_DIR/.venv"
COMPOSE_FILE="$ROOT_DIR/infra/compose/docker-compose.yml"
RUNTIME_DIR="$ROOT_DIR/.runtime/android-run"
LOG_DIR="$RUNTIME_DIR/logs"

API_PORT="${API_PORT:-8000}"
DEVICE_ID=""
API_BASE_URL_OVERRIDE=""
KEEP_BACKGROUND=false
SKIP_SEED=false
RESTART_SERVICES=false
USE_LOCAL_GEMMA=false

STARTED_PIDS=()
ADB_REVERSE_ACTIVE=false
ANDROID_EMULATOR=false
ANDROID_DEVICE_NAME=""
FLUTTER_EXTRA_ARGS=()

usage() {
  cat <<'EOF'
Uso:
  bash scripts/run_android_app.sh [opzioni] [-- argomenti extra flutter]

Opzioni:
  --device-id ID        Usa uno specifico device Android collegato (ID o nome Flutter).
  --api-base-url URL    Forza un API_BASE_URL specifico per Flutter.
  --local-gemma         Applica l'overlay env generato da scripts/setup_local_gemma_ollama.sh.
  --skip-seed           Non eseguire il seed demo.
  --restart-services    Riavvia backend/worker/beat per ricaricare la configurazione.
  --keep-background     Lascia attivi backend/worker/beat dopo l'uscita di Flutter.
  --help                Mostra questo aiuto.

Esempi:
  bash scripts/run_android_app.sh
  bash scripts/run_android_app.sh --device-id emulator-5554
  bash scripts/run_android_app.sh -- --debug
EOF
}

info() {
  printf '[ClinDiary] %s\n' "$*" >&2
}

fail() {
  printf '[ClinDiary] Errore: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf '[ClinDiary] Avviso: %s\n' "$*" >&2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Comando richiesto non trovato: $1"
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --device-id)
        shift
        [[ $# -gt 0 ]] || fail "Manca il valore per --device-id"
        DEVICE_ID="$1"
        ;;
      --api-base-url)
        shift
        [[ $# -gt 0 ]] || fail "Manca il valore per --api-base-url"
        API_BASE_URL_OVERRIDE="$1"
        ;;
      --local-gemma)
        USE_LOCAL_GEMMA=true
        ;;
      --skip-seed)
        SKIP_SEED=true
        ;;
      --restart-services)
        RESTART_SERVICES=true
        ;;
      --keep-background)
        KEEP_BACKGROUND=true
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      --)
        shift
        FLUTTER_EXTRA_ARGS=("$@")
        break
        ;;
      *)
        fail "Opzione non riconosciuta: $1"
        ;;
    esac
    shift
  done
}

load_env_files() {
  if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$ROOT_DIR/.env"
    set +a
  fi

  if [[ -f "$BACKEND_DIR/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$BACKEND_DIR/.env"
    set +a
  fi

  if [[ "$USE_LOCAL_GEMMA" == "true" ]]; then
    local local_profile generated_overlay
    local_profile="$BACKEND_DIR/.env.gemma-local.example"
    generated_overlay="$ROOT_DIR/.runtime/ollama-local/gemma-local.env"

    if [[ -f "$local_profile" ]]; then
      set -a
      # shellcheck disable=SC1091
      source "$local_profile"
      set +a
    fi

    if [[ -f "$generated_overlay" ]]; then
      set -a
      # shellcheck disable=SC1091
      source "$generated_overlay"
      set +a
      info "Overlay locale Gemma caricato da $generated_overlay"
    else
      warn "Overlay locale Gemma non trovato in $generated_overlay: uso solo i valori base del profilo."
    fi
  fi

  export DATABASE_URL="${DATABASE_URL:-postgresql+psycopg://clindiary:clindiary@localhost:5432/clindiary}"
  export REDIS_URL="${REDIS_URL:-redis://localhost:6379/0}"
  export MINIO_ENDPOINT="${MINIO_ENDPOINT:-localhost:9000}"
  export MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-minioadmin}"
  export MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-minioadmin}"
  export MINIO_BUCKET="${MINIO_BUCKET:-clindiary}"
  export MINIO_SECURE="${MINIO_SECURE:-false}"
  export PYTHONPATH="$ROOT_DIR/apps/backend"

}

ensure_backend_environment() {
  if [[ ! -x "$BACKEND_VENV/bin/python" ]]; then
    info "Creo il virtualenv backend..."
    python3 -m venv "$BACKEND_VENV"
  fi

  if ! "$BACKEND_VENV/bin/python" -c "import fastapi, celery, sqlalchemy" >/dev/null 2>&1; then
    info "Installo dipendenze backend..."
    "$BACKEND_VENV/bin/pip" install -e "$ROOT_DIR/apps/backend[dev,ocr]"
  fi
}

ensure_mobile_dependencies() {
  info "Aggiorno dipendenze Flutter..."
  (
    cd "$MOBILE_DIR"
    flutter pub get
  )
}

start_infra() {
  info "Avvio postgres, redis e minio..."
  docker compose -f "$COMPOSE_FILE" up -d postgres redis minio minio-init
}

run_migrations_and_seed() {
  info "Eseguo migration database..."
  (
    cd "$BACKEND_DIR"
    .venv/bin/alembic upgrade head
  )

  if [[ "$SKIP_SEED" == "false" ]]; then
    info "Eseguo seed demo..."
    (
      cd "$BACKEND_DIR"
      .venv/bin/clindiary-seed
    )
  fi
}

service_running() {
  local pattern="$1"
  pgrep -af "$pattern" >/dev/null 2>&1
}

stop_matching_processes() {
  local pattern="$1"
  local label="$2"

  if pgrep -af "$pattern" >/dev/null 2>&1; then
    info "Riavvio $label..."
    pkill -f "$pattern" >/dev/null 2>&1 || true
    sleep 1
  fi
}

backend_healthy() {
  curl -fsS "http://127.0.0.1:${API_PORT}/health" >/dev/null 2>&1
}

wait_for_backend() {
  local attempts=40
  local delay_seconds=1

  for ((i = 1; i <= attempts; i++)); do
    if backend_healthy; then
      info "Backend pronto su http://127.0.0.1:${API_PORT}"
      return 0
    fi
    sleep "$delay_seconds"
  done

  fail "Il backend non e diventato raggiungibile su http://127.0.0.1:${API_PORT}"
}

start_background_service() {
  local name="$1"
  local command="$2"
  local log_file="$LOG_DIR/${name}.log"

  info "Avvio $name..."
  bash -lc "cd '$ROOT_DIR' && $command" >"$log_file" 2>&1 &
  STARTED_PIDS+=("$!")
  info "$name attivo. Log: $log_file"
}

ensure_backend_services() {
  mkdir -p "$LOG_DIR"

  if [[ "$RESTART_SERVICES" == "true" ]]; then
    stop_matching_processes "app.main:app --app-dir $ROOT_DIR/apps/backend" "backend"
    stop_matching_processes "app.workers.celery_app.celery_app worker" "worker"
    stop_matching_processes "app.workers.celery_app.celery_app beat" "beat"
  fi

  if backend_healthy; then
    info "Backend gia attivo, non avvio una seconda istanza."
  else
    start_background_service \
      "backend" \
      "PYTHONPATH='$ROOT_DIR/apps/backend' '$BACKEND_VENV/bin/uvicorn' app.main:app --app-dir '$ROOT_DIR/apps/backend' --host 0.0.0.0 --port '$API_PORT' --reload"
    wait_for_backend
  fi

  if service_running "app.workers.celery_app.celery_app worker"; then
    info "Celery worker gia attivo, lo riuso."
  else
    start_background_service \
      "worker" \
      "PYTHONPATH='$ROOT_DIR/apps/backend' '$BACKEND_VENV/bin/celery' -A app.workers.celery_app.celery_app worker --loglevel=info"
  fi

  if service_running "app.workers.celery_app.celery_app beat"; then
    info "Celery beat gia attivo, lo riuso."
  else
    start_background_service \
      "beat" \
      "PYTHONPATH='$ROOT_DIR/apps/backend' '$BACKEND_VENV/bin/celery' -A app.workers.celery_app.celery_app beat --loglevel=info"
  fi
}

detect_android_device() {
  local devices_json
  local selected

  devices_json="$(flutter devices --machine 2>/dev/null)" || {
    fail "Impossibile eseguire 'flutter devices --machine'."
  }

  selected="$(
    DEVICES_JSON="$devices_json" DEVICE_ID="$DEVICE_ID" python3 <<'PY'
import json
import os
import sys

selected = os.environ.get("DEVICE_ID", "").strip()
raw = os.environ.get("DEVICES_JSON", "").strip()

if not raw:
    sys.exit(4)

try:
    devices = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(5)

android = [
    item
    for item in devices
    if item.get("isSupported") and str(item.get("targetPlatform", "")).startswith("android")
]

if not android:
    sys.exit(2)

if selected:
    for item in android:
        if item.get("id") == selected or item.get("name") == selected:
            print(
                f"{item['id']}|{'true' if item.get('emulator') else 'false'}|{item.get('name', item['id'])}"
            )
            break
    else:
        sys.exit(3)
else:
    first = android[0]
    print(f"{first['id']}|{'true' if first.get('emulator') else 'false'}|{first.get('name', first['id'])}")
PY
  )" || {
    case "$?" in
      2) fail "Nessun device Android collegato. Apri un emulator o collega il telefono." ;;
      3) fail "Il device richiesto con --device-id non e disponibile." ;;
      4) fail "Flutter non ha restituito alcun payload device in formato machine." ;;
      5) fail "L'output di 'flutter devices --machine' non e JSON valido." ;;
      *) fail "Impossibile leggere la lista dei device Flutter." ;;
    esac
  }

  IFS='|' read -r DEVICE_ID ANDROID_EMULATOR ANDROID_DEVICE_NAME <<<"$selected"
  info "Uso il device Android: $ANDROID_DEVICE_NAME ($DEVICE_ID)"
}

compute_host_ip() {
  local host_ip
  host_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}')"
  [[ -n "$host_ip" ]] || fail "Non riesco a determinare l'IP locale del computer."
  printf '%s' "$host_ip"
}

configure_android_networking() {
  if [[ -n "$API_BASE_URL_OVERRIDE" ]]; then
    printf '%s' "$API_BASE_URL_OVERRIDE"
    return 0
  fi

  if command -v adb >/dev/null 2>&1; then
    if adb -s "$DEVICE_ID" reverse "tcp:${API_PORT}" "tcp:${API_PORT}" >/dev/null 2>&1; then
      ADB_REVERSE_ACTIVE=true
      info "Networking Android configurato con adb reverse sulla porta ${API_PORT}."
      printf 'http://127.0.0.1:%s' "$API_PORT"
      return 0
    fi
  fi

  if [[ "$ANDROID_EMULATOR" == "true" ]]; then
    info "adb reverse non disponibile, uso 10.0.2.2 per l'emulatore."
    printf 'http://10.0.2.2:%s' "$API_PORT"
    return 0
  fi

  local host_ip
  host_ip="$(compute_host_ip)"
  info "adb reverse non disponibile, uso l'IP locale del PC: $host_ip"
  printf 'http://%s:%s' "$host_ip" "$API_PORT"
}

cleanup() {
  local exit_code=$?

  if [[ "$ADB_REVERSE_ACTIVE" == "true" ]] && command -v adb >/dev/null 2>&1; then
    adb -s "$DEVICE_ID" reverse --remove "tcp:${API_PORT}" >/dev/null 2>&1 || true
  fi

  if [[ "$KEEP_BACKGROUND" == "false" ]]; then
    for pid in "${STARTED_PIDS[@]}"; do
      if kill -0 "$pid" >/dev/null 2>&1; then
        kill "$pid" >/dev/null 2>&1 || true
      fi
    done
  fi

  exit "$exit_code"
}

main() {
  parse_args "$@"

  require_command docker
  require_command python3
  require_command flutter
  require_command curl

  trap cleanup EXIT INT TERM

  mkdir -p "$RUNTIME_DIR"
  load_env_files
  start_infra
  ensure_backend_environment
  run_migrations_and_seed
  ensure_backend_services
  ensure_mobile_dependencies
  detect_android_device

  local api_base_url
  local hackathon_demo_mode
  api_base_url="$(configure_android_networking)"
  hackathon_demo_mode="${HACKATHON_DEMO_MODE:-false}"
  info "API_BASE_URL usato da Flutter: $api_base_url"
  info "Hackathon demo mode: $hackathon_demo_mode"
  info "Credenziali demo: demo@clindiary.app / ChangeMe123!"

  (
    cd "$MOBILE_DIR"
    flutter run \
        -d "$DEVICE_ID" \
        --dart-define="API_BASE_URL=$api_base_url" \
        --dart-define="HACKATHON_DEMO_MODE=$hackathon_demo_mode" \
        --dart-define="GOOGLE_AUTH_CLIENT_ID=${GOOGLE_OAUTH_CLIENT_ID:-}" \
        "${FLUTTER_EXTRA_ARGS[@]}"
  )
}

main "$@"
