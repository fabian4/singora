#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_prereqs
setup_case_dir "token-unknown-session"
install_cleanup_trap
start_server
pair_with_approval

tmp_session="${TMP_ROOT}/session-mutated.json"
jq '.session_id = "00000000-0000-0000-0000-000000000099"' "$(session_path)" >"${tmp_session}"
mv "${tmp_session}" "$(session_path)"

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
  echo "unknown session case unexpectedly succeeded" >&2
  exit 1
fi

assert_file_contains "${TMP_ROOT}/token.stderr" "401 Unauthorized"
assert_no_pending
print_case_passed "token_unknown_session"
