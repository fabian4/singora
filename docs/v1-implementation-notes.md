# Sigora V1 Implementation Notes

## Suggested Workspace Layout

```text
sigora/
  crates/
    sigora-cli/
    sigorad-server/
    sigorad-ui-macos/
    sigora-proto/
    sigora-crypto/
    sigora-store/
```

Suggested crate responsibilities:

- `sigora-cli`: client CLI for `pair` and `token`
- `sigorad-server`: HTTP or socket API plus core runtime logic
- `sigorad-ui-macos`: menu bar app, approval prompts, import UI
- `sigora-proto`: request and response types, constants, error codes
- `sigora-crypto`: HMAC, nonce handling, and time-window validation
- `sigora-store`: SQLite and Keychain access layer

## Suggested Tech Stack

- CLI: `clap`
- transport: `axum` or `hyper`
- serialization: `serde`, `serde_json`
- SQLite: `rusqlite`
- crypto: `hmac`, `sha2`, `rand`
- time: `time` or `chrono`
- error handling: `thiserror`, `anyhow`
- logging: `tracing`, `tracing-subscriber`

## Runtime Flow

### Pair flow

1. `sigora pair` sends `POST /pair`.
2. The server creates a pending request and notifies the UI.
3. The UI shows request details and triggers macOS LocalAuthentication.
4. On approval, the server creates:
   - `session_id`
   - `session_key`
   - `expire_at`
5. The server stores only `session_key_hash`.
6. The client stores local pairing and session config.

### Token flow

1. `sigora token` loads the local session.
2. The client sends `session_id`, `provider`, `type?`, `alias`, `ts`, `nonce`, and `mac`.
3. The server validates:
   - session existence and expiration
   - allowed timestamp skew
   - nonce uniqueness
   - HMAC correctness
4. The server resolves `provider/type/alias` to a Keychain reference.
5. The secret value is read from Keychain.
6. The server returns `text/plain` with only the raw value.

## Protocol Notes

### `POST /pair`

Request example:

```json
{
  "client_id": "cli-001",
  "client_name": "codex",
  "device_name": "MacBook-Pro",
  "user_hint": "alice",
  "client_pubkey_fingerprint": "A1F9-3C7D",
  "request_origin": "10.0.1.12",
  "pair_timeout_sec": 60
}
```

Success response example:

```json
{
  "session_id": "s_abc123",
  "session_key": "base64-32bytes",
  "expire_at": 1710000000
}
```

Typical error cases:

- `408 timeout`
- `403 denied`

### `POST /token`

Request example:

```json
{
  "session_id": "s_abc123",
  "provider": "github",
  "type": "bearer_token",
  "alias": "work",
  "ts": 1710000010,
  "nonce": "n_7f2c...",
  "mac": "hex(hmac_sha256(session_key, canonical_string))"
}
```

Canonical string:

```text
session_id|provider|type|alias|ts|nonce
```

Success response:

```text
ghp_xxxxxxxxxxxxxxxxxxxx
```

Ambiguous type should return a conflict-style error rather than guessing.

## Storage Model

### `pairings`

```sql
CREATE TABLE pairings (
  client_id    TEXT PRIMARY KEY,
  device_name  TEXT,
  paired_at    INTEGER NOT NULL,
  revoked_at   INTEGER
);
```

### `sessions`

```sql
CREATE TABLE sessions (
  session_id         TEXT PRIMARY KEY,
  client_id          TEXT NOT NULL,
  session_key_hash   TEXT NOT NULL,
  expire_at          INTEGER NOT NULL,
  last_nonce         TEXT,
  created_at         INTEGER NOT NULL
);
```

### `credential_store`

```sql
CREATE TABLE credential_store (
  provider   TEXT NOT NULL,
  type       TEXT NOT NULL,
  alias      TEXT NOT NULL DEFAULT 'default',
  ref        TEXT NOT NULL,
  updated    INTEGER NOT NULL,
  expire     INTEGER,
  PRIMARY KEY (provider, type, alias)
);
```

Implementation constraint:

- SQLite stores metadata only
- raw token, cookie, or secret values stay in Keychain

## Credential Types

Initial types worth supporting in v1:

- `bearer_token`
- `oauth_token`
- `api_key`
- `jwt`
- `cookie`
- `aws_session`

For `aws_session`, the stored value can use a packed representation such as:

```text
access|secret|session
```

## CLI Surface

### `sigora pair`

Responsibilities:

- discover the local server automatically
- initiate pairing
- wait for approval
- persist local session configuration

### `sigora token`

Usage:

```bash
sigora token --provider <provider> [--type <type>] [--alias <alias>]
```

Behavior:

- success writes only the credential value to `stdout`
- failure writes an error to `stderr` and exits non-zero

Example:

```bash
export GITHUB_TOKEN="$(sigora token --provider github --type bearer_token --alias work)"
```

## macOS UI Requirements

The v1 UI is intentionally small and security-oriented.

### Main form

- menu bar icon
- compact menu
- modal or pop-up detail windows when needed
- LocalAuthentication for sensitive approvals

### Primary menu items

- Status
- Pair Requests
- Token Requests
- Import Credential
- Credentials
- Logs
- Settings
- Quit

### Pair approval dialog

Should show:

- `client_name`
- `client_id`
- `device_name`
- `user_hint`
- `client_pubkey_fingerprint`
- `request_origin`
- session TTL selector
- countdown until timeout

Approval options:

- `10 min`
- `30 min`
- `60 min`

### Token approval dialog

For high-risk requests, show:

- `provider`
- `type`
- `alias`
- `client_id`
- risk level

Sensitive approvals must go through system authentication.

### Import flow

Fields:

- provider
- type
- alias
- value

Security constraints:

- never display the full secret after import
- log import results without the secret value
- confirm overwrite when `(provider, type, alias)` already exists

## Security Controls

- short session TTL, with `10 min` as the default
- HMAC-SHA256 request authentication
- timestamp window validation
- nonce replay protection
- secret redaction in logs
- no plaintext import through command-line arguments

## Suggested Milestones

1. Create the Rust workspace and shared protocol crate.
2. Implement local server, storage, and basic audit logging.
3. Implement `sigora pair` and `sigora token`.
4. Add Keychain-backed credential import and retrieval.
5. Add the macOS menu bar approval and import flows.
6. Add revocation, expiry cleanup, and end-to-end tests.
