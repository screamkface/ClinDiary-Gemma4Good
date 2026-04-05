#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${CLINDIARY_BASE_URL:-http://127.0.0.1:8000}"
EMAIL="${CLINDIARY_EMAIL:-demo@clindiary.app}"
PASSWORD="${CLINDIARY_PASSWORD:-ChangeMe123!}"
REFERENCE_DATE="${CLINDIARY_REFERENCE_DATE:-$(date +%F)}"
EXPECT_FALLBACK="${EXPECT_FALLBACK:-0}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

login_body="$tmp_dir/login.json"
status_body="$tmp_dir/local_status.json"
summary_body="$tmp_dir/private_local_daily.json"

curl -sS \
  -X POST \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}" \
  "${BASE_URL}/api/v1/auth/login" \
  > "$login_body"

token="$(python3 - <<'PY' "$login_body"
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
print(payload.get("access_token", ""))
PY
)"

if [ -z "$token" ]; then
  echo "login_failed=true"
  cat "$login_body"
  exit 2
fi

auth_header="Authorization: Bearer ${token}"

curl -sS \
  -H "$auth_header" \
  "${BASE_URL}/api/v1/insights/local-status" \
  > "$status_body"

echo "== local_status =="
python3 - <<'PY' "$status_body"
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
for key in (
    "enabled",
    "provider",
    "active_provider_label",
    "runtime_mode",
    "backend",
    "model_name",
    "configured_base_url_present",
    "fallback_provider",
    "is_cloud_bypassed_for_this_request",
):
    print(f"{key}={payload.get(key)}")
PY

curl -sS \
  -H "$auth_header" \
  "${BASE_URL}/api/v1/insights/daily/private-local?reference_date=${REFERENCE_DATE}" \
  > "$summary_body"

echo
echo "== private_local_daily =="
python3 - <<'PY' "$summary_body" "$EXPECT_FALLBACK"
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
expect_fallback = sys.argv[2] == "1"
provider = payload.get("provider_name")
print(f"id={payload.get('id')}")
print(f"provider={provider}")
print(f"model={payload.get('model_name')}")
content = str(payload.get("content", "")).strip().replace("\n", " ")
print(f"content_preview={content[:240]}")
if expect_fallback and provider != "rule_based":
    raise SystemExit("expected_fallback_but_local_provider_was_used")
PY
