# Sigora V1 MVP Spec

## Goal

Deliver a usable Sigora v1 closed loop without requiring provider-side changes:

- agents do not hold long-lived credentials
- agents obtain short-lived or controlled access through Sigora
- providers continue using existing token or OAuth-based authentication
- the full flow is auditable, revocable, and time-bounded

## Delivery Shape

- client binary: `sigora`
- server binary: `sigorad`
- client commands: `sigora pair`, `sigora token`
- server commands: `sigorad start|stop|status|logs|approve|deny|import`
- server runtime: macOS only for v1
- server UX: menu bar icon with lightweight approval and import flows
- implementation language: Rust for both client and server

## In Scope

### 1. Local AIR runtime

- single-machine runtime
- local communication via Unix domain socket or localhost HTTP

### 2. Pair and session protocol

- initial pairing flow
- issued `agent_id`
- short-lived `session_id` with expiration

### 3. Credential management and distribution

- agents submit `action` and `resource` requests
- Sigora evaluates policy before access is returned
- response body contains only the credential value for CLI piping and environment injection

### 4. Minimal policy engine

- `allow` and `deny` rules
- policy inputs based on agent, action, and resource
- default deny

### 5. Audit logging

- pairing
- session creation
- credential issue
- denial
- expiration
- revocation

### 6. Manual revocation

- revoke active authorization by `agent_id` or `session_id`

### 7. Credential import

- menu bar UI import as the primary path
- `sigorad import` as the automation path
- import value must come through `stdin`, not command-line flags

## Out Of Scope

- provider-native signature verification
- deep HSM or TPM integration
- multi-tenant admin console
- advanced policy language

## Primary User Stories

1. A user can approve an agent pairing and constrain its capability scope.
2. An agent can request a credential through `sigora token`.
3. An administrator can inspect audit records and revoke authorization.

## Functional Requirements

- `FR-01 Pairing`: one-time pairing creates an `agent_id`
- `FR-02 Session`: create, validate, and expire `session_id`
- `FR-03 Token`: return a usable provider credential value for an authorized request
- `FR-04 Policy`: every request is checked by policy before release
- `FR-05 Audit`: all critical operations write audit events
- `FR-06 Revoke`: active sessions and grants can be revoked manually
- `FR-07 Discovery`: the client can discover the local server
- `FR-08 Consent UI`: sensitive actions require server-side user confirmation
- `FR-09 CLI`: the client surface is limited to `pair` and `token`
- `FR-10 System Auth`: high-sensitivity confirmation uses macOS system authentication
- `FR-11 Server Entry Points`: menu bar UX and `sigorad` CLI share the same backend
- `FR-12 Import`: both UI and CLI import use one storage and audit path

## Non-Functional Requirements

- Security: long-lived credentials must not be stored in the agent
- Reliability: the single-machine flow should recover cleanly from common failures
- Observability: failures must be traceable in logs
- Performance: end-user token issuance latency should stay within interactive expectations
- Platform fit: the server should run stably on macOS
- Engineering consistency: both binaries use Rust
- Trust chain: do not replace macOS system authentication with a custom password prompt

## Minimal Data Model

- `agent_id`: paired agent identity
- `pairings`: `client_id`, `device_name`, `paired_at`, `revoked_at`
- `sessions`: `session_id`, `client_id`, `session_key_hash`, `expire_at`, `last_nonce`, `created_at`
- `grant`: authorization record over `agent`, `action`, `resource`, and `ttl`
- `credential_store`: `provider`, `type`, `alias`, `ref`, `updated`, `expire`
- `ref`: keychain entry reference
- `audit_event`: `time`, `actor`, `decision`, `reason`

Recommended uniqueness constraint:

```text
UNIQUE(provider, type, alias)
```

SQLite stores metadata only. Raw credential values should live in Keychain.

## Minimal API Draft

### `POST /pair`

Request fields:

- `client_id`
- `client_name`
- `device_name`
- `user_hint`
- `client_pubkey_fingerprint`
- `request_origin`
- `pair_timeout_sec` with a default of 60

Behavior:

- blocks while waiting for the user to approve in UI
- returns timeout if no decision arrives before deadline
- user chooses session duration, defaulting to `10 min`
- success returns `session_id`, `session_key`, and `expire_at`

### `POST /token`

Request fields:

- `session_id`
- `provider`
- `type`
- `alias`, default `default`
- `ts`
- `nonce`
- `mac`, where `mac = HMAC(session_key, session_id|provider|type|alias|ts|nonce)`

`type` omission rule:

- if `provider + alias` maps to exactly one credential type, the server selects it
- if multiple candidate types exist, the server rejects the request and requires explicit `type`

Response:

- `text/plain`
- body is only the raw token or secret value

Example:

```text
ghp_xxxxxxxxxxxxxxxxxxxx
```

## Credential Import Flows

### UI import

1. User opens the import screen from the menu bar app.
2. User enters `provider`, `type`, `alias`, and the secret value.
3. The server writes the secret to Keychain and stores the reference in SQLite.
4. An audit event records the result.

### CLI import

Example:

```bash
echo "ghp_xxx" | sigorad import --provider github --type bearer_token --alias work
```

Rules:

- the secret value is read from `stdin` only
- `--value <token>` is not allowed
- CLI import uses the same backend storage and audit path as UI import

## Acceptance Criteria

- the flow `pair -> session -> credential issue -> provider call` can be demonstrated end to end
- unauthorized requests are rejected and logged
- revoked or expired sessions can no longer fetch credentials
- imported credentials can be fetched through `sigora token`
- sensitive approval paths trigger macOS system authentication
