#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
E2E_ROOT="${REPO_ROOT}/scripts/e2e"
ORIGINAL_HOME="${HOME:-}"
TMP_ROOT=""
SERVER_PID=""
SERVER_LOG=""
RUN_SIGORA_PID=""
SIGORA_BASE_URL="${SIGORA_BASE_URL:-}"

require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || {
    echo "missing required command: ${cmd}" >&2
    exit 1
  }
}

setup_case_dir() {
  local case_name="$1"
  TMP_ROOT="$(mktemp -d "/tmp/sigora-e2e-${case_name}.XXXXXX")"
  export CARGO_HOME="${CARGO_HOME:-${ORIGINAL_HOME}/.cargo}"
  export RUSTUP_HOME="${RUSTUP_HOME:-${ORIGINAL_HOME}/.rustup}"
  export HOME="${TMP_ROOT}/home"
  export SIGORAD_BIND_ADDR="${SIGORAD_BIND_ADDR:-127.0.0.1:$(random_port)}"
  export SIGORA_BASE_URL="${SIGORA_BASE_URL:-http://${SIGORAD_BIND_ADDR}}"
  mkdir -p "${HOME}"
  SERVER_LOG="${TMP_ROOT}/sigorad.log"
}

random_port() {
  echo $((18000 + (RANDOM % 20000)))
}

cleanup() {
  if [[ -n "${SERVER_PID}" ]]; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" >/dev/null 2>&1 || true
    SERVER_PID=""
  fi
  if [[ "${SIGORA_E2E_KEEP_TMP:-0}" == "1" ]]; then
    if [[ -n "${TMP_ROOT}" ]]; then
      echo "preserved e2e tmp dir: ${TMP_ROOT}" >&2
    fi
    return 0
  fi
  if [[ -n "${TMP_ROOT}" && -d "${TMP_ROOT}" ]]; then
    rm -rf "${TMP_ROOT}"
  fi
}

install_cleanup_trap() {
  trap cleanup EXIT
}

start_server() {
  (
    cd "${REPO_ROOT}"
    cargo run --quiet -p sigorad-server
  ) >"${SERVER_LOG}" 2>&1 &
  SERVER_PID="$!"
  wait_for_server
}

wait_for_server() {
  local attempts=0
  until curl -fsS "${SIGORA_BASE_URL}/health" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ ${attempts} -ge 60 ]]; then
      echo "sigorad-server did not become healthy" >&2
      cat "${SERVER_LOG}" >&2 || true
      exit 1
    fi
    sleep 0.25
  done
}

run_sigora_bg() {
  local stdout_file="$1"
  local stderr_file="$2"
  shift 2
  (
    cd "${REPO_ROOT}"
    cargo run --quiet -p sigora-cli -- "$@"
  ) >"${stdout_file}" 2>"${stderr_file}" &
  RUN_SIGORA_PID="$!"
}

wait_for_pending_kind() {
  local expected_kind="$1"
  local attempts=0
  while true; do
    local pending
    pending="$(curl -fsS "${SIGORA_BASE_URL}/ui/pending")"
    local count
    count="$(jq --arg kind "${expected_kind}" '[.[] | select(.request_kind == $kind)] | length' <<<"${pending}")"
    if [[ "${count}" != "0" ]]; then
      jq -r --arg kind "${expected_kind}" '.[] | select(.request_kind == $kind) | .id' <<<"${pending}" | head -n 1
      return 0
    fi
    attempts=$((attempts + 1))
    if [[ ${attempts} -ge 80 ]]; then
      echo "timed out waiting for pending approval kind=${expected_kind}" >&2
      echo "${pending}" >&2
      exit 1
    fi
    sleep 0.25
  done
}

post_decision() {
  local approval_id="$1"
  local approved="$2"
  local note="$3"
  curl -fsS \
    -X POST \
    -H "content-type: application/json" \
    "${SIGORA_BASE_URL}/ui/decision" \
    -d "$(jq -nc --arg id "${approval_id}" --argjson approved "${approved}" --arg note "${note}" '{approval_id: $id, approved: $approved, note: $note}')"
}

pair_with_approval() {
  local pair_out="${TMP_ROOT}/pair.stdout"
  local pair_err="${TMP_ROOT}/pair.stderr"
  run_sigora_bg "${pair_out}" "${pair_err}" pair
  local approval_id
  approval_id="$(wait_for_pending_kind "pair")"
  post_decision "${approval_id}" true "approved by e2e pair helper" >/dev/null
  wait "${RUN_SIGORA_PID}"
  grep -q '^paired$' "${pair_out}" || {
    echo "pair command did not report success" >&2
    cat "${pair_out}" >&2 || true
    cat "${pair_err}" >&2 || true
    exit 1
  }
}

assert_file_contains() {
  local path="$1"
  local expected="$2"
  if ! grep -Fq "${expected}" "${path}"; then
    echo "expected ${path} to contain: ${expected}" >&2
    echo "--- ${path} ---" >&2
    cat "${path}" >&2 || true
    exit 1
  fi
}

assert_no_pending() {
  local pending
  pending="$(curl -fsS "${SIGORA_BASE_URL}/ui/pending")"
  local count
  count="$(jq 'length' <<<"${pending}")"
  if [[ "${count}" != "0" ]]; then
    echo "expected no pending approvals, got ${count}" >&2
    echo "${pending}" >&2
    exit 1
  fi
}

print_case_passed() {
  local case_name="$1"
  echo "[pass] ${case_name}"
}

require_prereqs() {
  require_cmd cargo
  require_cmd curl
  require_cmd jq
}

session_path() {
  echo "${HOME}/.sigora/session.json"
}

current_session_id() {
  jq -r '.session_id' "$(session_path)"
}
