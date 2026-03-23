#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_prereqs
setup_case_dir "pair-timeout"
install_cleanup_trap
start_server

pair_out="${TMP_ROOT}/pair-timeout.body"
pair_status="$(curl -sS -o "${pair_out}" -w "%{http_code}" \
  -X POST \
  -H "content-type: application/json" \
  "${SIGORA_BASE_URL}/pair" \
  -d '{
    "client_id":"timeout-cli",
    "client_name":"sigora-timeout",
    "device_name":"test-device",
    "user_hint":"timeout-case",
    "client_pubkey_fingerprint":"dev-fingerprint",
    "request_origin":"127.0.0.1",
    "pair_timeout_sec":1
  }')"

[[ "${pair_status}" == "408" ]] || {
  echo "expected 408 from pair timeout, got ${pair_status}" >&2
  cat "${pair_out}" >&2 || true
  exit 1
}
assert_file_contains "${pair_out}" "pair request timed out"
assert_no_pending
print_case_passed "pair_timeout"
