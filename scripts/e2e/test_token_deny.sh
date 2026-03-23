#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_prereqs
setup_case_dir "token-deny"
install_cleanup_trap
start_server
pair_with_approval

token_out="${TMP_ROOT}/token.stdout"
token_err="${TMP_ROOT}/token.stderr"
if (
  cd "${REPO_ROOT}"
  cargo run --quiet -p sigora-cli -- token \
    --provider github \
    --action deploy \
    --resource production/api \
    --type bearer_token \
    --alias work
) >"${token_out}" 2>"${token_err}"; then
  echo "token command unexpectedly succeeded" >&2
  exit 1
fi

assert_file_contains "${token_err}" "403 Forbidden"
assert_no_pending
print_case_passed "token_deny"
