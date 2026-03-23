#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_prereqs
setup_case_dir "token-revoked-session"
install_cleanup_trap
start_server
pair_with_approval

session_id="$(current_session_id)"
revoke_status="$(curl -sS -o "${TMP_ROOT}/revoke.body" -w "%{http_code}" \
  -X POST \
  -H "content-type: application/json" \
  "${SIGORA_BASE_URL}/revoke/session" \
  -d "$(jq -nc --arg session_id "${session_id}" '{session_id: $session_id}')")"

[[ "${revoke_status}" == "200" ]] || {
  echo "expected revoke to succeed, got ${revoke_status}" >&2
  cat "${TMP_ROOT}/revoke.body" >&2 || true
  exit 1
}
assert_file_contains "${TMP_ROOT}/revoke.body" '"revoked":true'

token_out="${TMP_ROOT}/token.stdout"
if (
  cd "${REPO_ROOT}"
  cargo run --quiet -p sigora-cli -- token \
    --provider github \
    --action repo.read \
    --resource sigora/core \
    --type bearer_token \
    --alias work
) >"${token_out}" 2>"${TMP_ROOT}/token.stderr"; then
  echo "revoked session case unexpectedly succeeded" >&2
  exit 1
fi

assert_file_contains "${TMP_ROOT}/token.stderr" "401 Unauthorized"
assert_no_pending
print_case_passed "token_revoked_session"
