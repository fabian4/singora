#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_prereqs
setup_case_dir "pair-approve"
install_cleanup_trap
start_server

pair_out="${TMP_ROOT}/pair.stdout"
pair_err="${TMP_ROOT}/pair.stderr"
run_sigora_bg "${pair_out}" "${pair_err}" pair
approval_id="$(wait_for_pending_kind "pair")"
post_decision "${approval_id}" true "approved by pair e2e case" >/dev/null
if ! wait "${RUN_SIGORA_PID}"; then
  cat "${pair_out}" >&2 || true
  cat "${pair_err}" >&2 || true
  cat "${SERVER_LOG}" >&2 || true
  exit 1
fi

assert_file_contains "${pair_out}" "paired"
assert_file_contains "${pair_out}" "session_id="
[[ -f "${HOME}/.sigora/session.json" ]] || {
  echo "session file was not created" >&2
  exit 1
}
assert_no_pending
print_case_passed "pair_approve"
