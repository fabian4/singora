#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

cases=(
  "test_pair_approve.sh"
  "test_pair_deny.sh"
  "test_pair_timeout.sh"
  "test_token_allow.sh"
  "test_token_challenge_approve.sh"
  "test_token_deny.sh"
  "test_token_timeout.sh"
  "test_token_unknown_session.sh"
  "test_token_expired_session.sh"
  "test_token_revoked_session.sh"
)

for case_file in "${cases[@]}"; do
  "${ROOT}/${case_file}"
done

echo "all e2e cases passed"
