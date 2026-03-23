#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_prereqs
setup_case_dir "token-timeout"
export SIGORAD_TOKEN_APPROVAL_TIMEOUT_SEC=2
install_cleanup_trap
start_server
pair_with_approval

token_out="${TMP_ROOT}/token.stdout"
if (
  cd "${REPO_ROOT}"
  cargo run --quiet -p sigora-cli -- token \
    --provider aws \
    --action secrets.read \
    --resource team/backend \
    --type bearer_token \
    --alias admin
) >"${token_out}" 2>"${TMP_ROOT}/token.stderr"; then
  echo "token timeout case unexpectedly succeeded" >&2
  exit 1
fi

assert_file_contains "${TMP_ROOT}/token.stderr" "408 Request Timeout"
assert_no_pending
print_case_passed "token_timeout"
