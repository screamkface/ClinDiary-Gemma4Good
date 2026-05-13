#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$SCRIPT_DIR/../apps/mobile"

cd "$MOBILE_DIR"
dart run tool/localization_pipeline.dart "$@"
