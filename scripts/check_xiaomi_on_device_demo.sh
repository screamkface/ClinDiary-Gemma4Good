#!/usr/bin/env bash
set -Eeuo pipefail

PACKAGE_NAME="${PACKAGE_NAME:-it.clindiary.clindiary}"
DEVICE_ID=""
API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:8000}"

usage() {
  cat <<'EOF'
Uso:
  bash scripts/check_xiaomi_on_device_demo.sh [opzioni]

Opzioni:
  --device-id ID       Usa uno specifico device adb.
  --api-base-url URL   URL health del backend locale. Default: http://127.0.0.1:8000
  --help               Mostra questo aiuto.
EOF
}

fail() {
  printf '[ClinDiary] Errore: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '[ClinDiary] %s\n' "$*" >&2
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
        API_BASE_URL="$1"
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

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Comando richiesto non trovato: $1"
}

resolve_device() {
  if [[ -n "$DEVICE_ID" ]]; then
    return 0
  fi
  mapfile -t devices < <(adb devices | awk 'NR > 1 && $2 == "device" {print $1}')
  case "${#devices[@]}" in
    0) fail "Nessun device adb disponibile." ;;
    1) DEVICE_ID="${devices[0]}" ;;
    *) fail "Più device collegati. Usa --device-id." ;;
  esac
}

adb_cmd() {
  adb -s "$DEVICE_ID" "$@"
}

shell_prop() {
  adb_cmd shell getprop "$1" 2>/dev/null | tr -d '\r'
}

main() {
  parse_args "$@"
  require_command adb
  require_command curl
  resolve_device

  local model_dir
  model_dir="/sdcard/Android/data/${PACKAGE_NAME}/files/models"

  info "Device adb: $DEVICE_ID"
  printf 'Modello dispositivo: %s\n' "$(shell_prop ro.product.marketname || true)"
  printf 'Product model: %s\n' "$(shell_prop ro.product.model || true)"
  printf 'SoC: %s\n' "$(shell_prop ro.soc.model || true)"
  printf 'Android: %s\n' "$(shell_prop ro.build.version.release || true)"
  printf 'RAM totale: %s\n' "$(adb_cmd shell "grep MemTotal /proc/meminfo | tr -d '\r'" 2>/dev/null || true)"

  printf '\n== Package ClinDiary ==\n'
  if adb_cmd shell pm list packages | tr -d '\r' | grep -q "$PACKAGE_NAME"; then
    echo "Installato: sì"
  else
    echo "Installato: no"
  fi

  printf '\n== Modelli LiteRT-LM ==\n'
  adb_cmd shell "ls -lh '$model_dir' 2>/dev/null" || echo "Nessun modello trovato in $model_dir"

  printf '\n== Backend ==\n'
  if curl -fsS "$API_BASE_URL/health" >/dev/null 2>&1; then
    echo "Backend raggiungibile: sì ($API_BASE_URL/health)"
  else
    echo "Backend raggiungibile: no ($API_BASE_URL/health)"
  fi

  cat <<EOF

== Checklist demo Xiaomi 15T Pro ==
1. Apri ClinDiary sul telefono.
2. Vai in Recap AI -> Giorno -> Sul dispositivo.
3. Se necessario importa il file .litertlm dalla schermata o dalla proof card.
4. Controlla:
   - Runtime: LiteRT-LM Android
   - Backend usato: GPU o CPU
   - Modello rilevato
   - Cloud esterno usato: No
5. Genera o rigenera il recap.

Suggerimento recording:
- usa luminosità fissa alta
- chiudi AI Edge Gallery e altre app pesanti prima della demo
- lascia già aperta la schermata Recap AI sul telefono
EOF
}

main "$@"
