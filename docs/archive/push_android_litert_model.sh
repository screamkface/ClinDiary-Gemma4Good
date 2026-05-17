#!/usr/bin/env bash
set -Eeuo pipefail

PACKAGE_NAME="${PACKAGE_NAME:-it.clindiary.clindiary}"
DEVICE_ID=""
MODEL_PATH=""
TARGET_NAME=""

usage() {
  cat <<'EOF'
Uso:
  bash scripts/push_android_litert_model.sh /percorso/modello.litertlm [opzioni]

Opzioni:
  --device-id ID     Usa uno specifico device adb.
  --target-name NAME Salva il file con un nome specifico sul telefono.
  --help             Mostra questo aiuto.

Il modello viene copiato in:
  /sdcard/Android/data/it.clindiary.clindiary/files/models/
EOF
}

fail() {
  printf '[ClinDiary] Errore: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '[ClinDiary] %s\n' "$*" >&2
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
      --target-name)
        shift
        [[ $# -gt 0 ]] || fail "Manca il valore per --target-name"
        TARGET_NAME="$1"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      --*)
        fail "Opzione non riconosciuta: $1"
        ;;
      *)
        [[ -z "$MODEL_PATH" ]] || fail "Specifica un solo file modello."
        MODEL_PATH="$1"
        ;;
    esac
    shift
  done
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

main() {
  parse_args "$@"
  [[ -n "$MODEL_PATH" ]] || {
    usage
    exit 1
  }

  require_command adb
  [[ -f "$MODEL_PATH" ]] || fail "File modello non trovato: $MODEL_PATH"
  [[ "$MODEL_PATH" == *.litertlm ]] || fail "Il file deve avere estensione .litertlm"

  resolve_device

  local target_dir target_file
  target_dir="/sdcard/Android/data/${PACKAGE_NAME}/files/models"
  target_file="${TARGET_NAME:-$(basename "$MODEL_PATH")}"

  info "Device: $DEVICE_ID"
  info "Creo directory modelli: $target_dir"
  adb_cmd shell "mkdir -p '$target_dir'"

  info "Copio $(basename "$MODEL_PATH") su $target_dir/$target_file"
  adb_cmd push "$MODEL_PATH" "$target_dir/$target_file"

  info "Verifica file sul telefono"
  adb_cmd shell "ls -lh '$target_dir'"

  cat <<EOF

Modello copiato.
Percorso atteso da ClinDiary:
  $target_dir/$target_file

Passi successivi:
1. Apri ClinDiary sul telefono.
2. Vai in Recap AI.
3. Seleziona Giorno -> Sul dispositivo.
4. Controlla la proof card: dovrebbe mostrare il modello rilevato.
EOF
}

main "$@"
