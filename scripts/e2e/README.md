# E2E Shell Cases

These scripts exercise the Rust-only loop around `sigorad-server` and `sigora-cli`.

## Coverage

- `test_pair_approve.sh`: pair request is approved and writes `~/.sigora/session.json`
- `test_pair_deny.sh`: pair request is denied and returns `403`
- `test_pair_timeout.sh`: pair request times out when no UI decision arrives
- `test_token_allow.sh`: low-risk read-only token request is auto-allowed by policy
- `test_token_challenge_approve.sh`: sensitive token request enters manual approval and succeeds after approval
- `test_token_deny.sh`: production privileged request is denied by policy
- `test_token_timeout.sh`: sensitive token request times out without approval
- `test_token_unknown_session.sh`: token request with an unknown session returns `401`
- `test_token_expired_session.sh`: token request with an expired paired session returns `401`
- `test_token_revoked_session.sh`: token request with a revoked session returns `401`

## Run

From the repository root:

```bash
bash scripts/e2e/run.sh
```

Each case uses a temporary `HOME` so it does not modify the real local `~/.sigora`.
