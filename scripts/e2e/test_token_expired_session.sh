#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_prereqs
setup_case_dir "token-expired-session"
export SIGORAD_SESSION_TTL_SEC=1
install_cleanup_trap
start_server
pair_with_approval
sleep 2

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
  echo "expired session case unexpectedly succeeded" >&2
  exit 1
fi

assert_file_contains "${TMP_ROOT}/token.stderr" "401 Unauthorized"
assert_no_pending
print_case_passed "token_expired_session"
