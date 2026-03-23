#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_prereqs
setup_case_dir "pair-deny"
install_cleanup_trap
start_server

pair_out="${TMP_ROOT}/pair.stdout"
pair_err="${TMP_ROOT}/pair.stderr"
run_sigora_bg "${pair_out}" "${pair_err}" pair
approval_id="$(wait_for_pending_kind "pair")"
post_decision "${approval_id}" false "denied by pair e2e case" >/dev/null

if wait "${RUN_SIGORA_PID}"; then
  echo "pair command unexpectedly succeeded" >&2
  exit 1
fi

assert_file_contains "${pair_err}" "403 Forbidden"
[[ ! -f "${HOME}/.sigora/session.json" ]] || {
  echo "session file should not exist after denied pair" >&2
  exit 1
}
assert_no_pending
print_case_passed "pair_deny"
