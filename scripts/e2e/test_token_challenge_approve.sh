#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_prereqs
setup_case_dir "token-challenge-approve"
install_cleanup_trap
start_server
pair_with_approval

token_out="${TMP_ROOT}/token.stdout"
token_err="${TMP_ROOT}/token.stderr"
run_sigora_bg "${token_out}" "${token_err}" token --provider aws --action secrets.read --resource team/backend --type bearer_token --alias admin
approval_id="$(wait_for_pending_kind "token")"

pending_json="$(curl -fsS "${SIGORA_BASE_URL}/ui/pending")"
policy_summary="$(jq -r --arg id "${approval_id}" '.[] | select(.id == $id) | .token_details.policy_summary' <<<"${pending_json}")"
if [[ "${policy_summary}" != Challenge* ]]; then
  echo "expected challenge policy summary, got: ${policy_summary}" >&2
  exit 1
fi

post_decision "${approval_id}" true "approved by token challenge e2e case" >/dev/null
if ! wait "${RUN_SIGORA_PID}"; then
  cat "${token_out}" >&2 || true
  cat "${token_err}" >&2 || true
  cat "${SERVER_LOG}" >&2 || true
  exit 1
fi

assert_file_contains "${token_out}" "sigora-dev-token:aws:admin"
assert_no_pending
print_case_passed "token_challenge_approve"
