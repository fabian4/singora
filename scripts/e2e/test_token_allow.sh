#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_prereqs
setup_case_dir "token-allow"
install_cleanup_trap
start_server
pair_with_approval

token_out="${TMP_ROOT}/token.stdout"
token_err="${TMP_ROOT}/token.stderr"
(
  cd "${REPO_ROOT}"
  cargo run --quiet -p sigora-cli -- token \
    --provider github \
    --action repo.read \
    --resource sigora/core \
    --type bearer_token \
    --alias work
) >"${token_out}" 2>"${token_err}"

assert_file_contains "${token_out}" "sigora-dev-token:github:work"
assert_no_pending
print_case_passed "token_allow"
