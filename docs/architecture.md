# Sigora Architecture Design

## 1. Purpose

This document defines the target architecture for Sigora as a secure runtime between agents and external providers.

It has two goals:

1. describe the production shape of Sigora as an Agent Identity Runtime
2. define a practical v1 architecture that can be implemented without provider-side changes

The document is intentionally split between:

- a long-term architecture model centered on proof-based invocation
- a near-term compatibility architecture centered on controlled credential release

## 2. Problem Statement

Agents, CLIs, and automation tools usually access providers by holding bearer credentials directly:

```text
agent -> token/API key/cookie -> provider
```

That model is weak for agentic systems because:

- secrets are copied into untrusted execution environments
- providers cannot distinguish approved agent behavior from raw credential reuse
- user approval and policy enforcement happen outside the runtime, if at all
- auditing is fragmented across local tools and providers

Sigora introduces a controlled invocation layer:

```text
agent -> Sigora -> provider
```

Sigora becomes the control plane for identity, policy, approval, secret handling, and audit.

## 3. Design Goals

- Credential containment: long-lived secrets remain inside Sigora
- Minimal agent trust: agent runtimes are treated as untrusted by default
- Explicit authorization: all requests are evaluated against policy
- User-controlled execution: sensitive requests can require local approval
- Auditable runtime: pairing, issuance, denial, expiration, and revocation are logged
- Incremental adoption: v1 works with existing providers; v2 supports proof-native verification
- Clear implementation path: the architecture must map cleanly to a Rust codebase

## 4. Architectural Overview

Sigora is the reference implementation of:

- AIR: Agent Identity Runtime
- AIP: Agent Invocation Protocol

### 4.1 Long-Term Model

The long-term model is proof-based:

```text
agent -> invocation request -> Sigora -> signed invocation proof -> provider
```

The provider verifies the proof using a registered public key and provider-side authorization.

### 4.2 V1 Compatibility Model

The first shippable model is compatibility-first:

```text
agent -> Sigora -> provider-compatible credential/access -> provider
```

In v1, Sigora still controls secrets centrally, but may return a provider-compatible value when necessary so existing tools can work unchanged.

This is not the end-state architecture, but it is the shortest path to a working system.

## 5. System Context

### 5.1 Roles

#### User

- owns provider accounts and permissions
- runs and controls Sigora
- approves pairing and sensitive operations

#### Agent

- AI assistant, CLI, automation script, or local tool
- requests capability from Sigora
- must not store long-lived provider credentials

#### Sigora Runtime

- enforces trust boundaries
- stores credential metadata and secrets
- issues or signs access
- records audit trails

#### Provider

- external platform such as GitHub, AWS, Kubernetes, or SaaS APIs
- in v1 consumes existing auth material
- in v2 verifies invocation proofs directly

### 5.2 Trust Boundaries

Sigora is the main trust boundary in the architecture.

```text
+-------------------+      +---------------------------+      +------------------+
| Untrusted Agent   | ---> | Sigora Trusted Runtime    | ---> | External Provider|
| CLI / Agent / Bot |      | Policy / Secrets / Audit  |      | GitHub / AWS /   |
|                   |      | Approval / Signing        |      | K8s / SaaS       |
+-------------------+      +---------------------------+      +------------------+
```

Trust assumptions:

- the agent environment may be compromised or poorly isolated
- the Sigora runtime is user-controlled and hardened relative to the agent
- the provider remains the final execution authority for the external operation

## 6. Core Concepts

### 6.1 Agent Identity

An `agent_id` or `identity_id` representing the caller relationship to Sigora or, in v2, to the provider trust domain.

Typical fields:

- stable identifier
- display name
- public key or fingerprint
- allowed scopes or linked policies

### 6.2 Pairing

Pairing is the initial trust-establishment flow between an agent and the Sigora runtime.

Output:

- paired caller identity
- approved metadata about the agent endpoint
- initial session material

### 6.3 Session

A short-lived authenticated channel between agent and Sigora.

Properties:

- bounded TTL
- replay protection
- revocable
- linked to one paired caller

### 6.4 Invocation Request

A normalized request representing an external action.

Representative fields:

- provider
- action
- resource
- optional credential type or access mode
- timestamp
- nonce
- request MAC or signature

### 6.5 Invocation Proof

The long-term replacement for exported credentials. A proof binds:

- caller identity
- action
- resource
- payload or payload digest
- freshness metadata

## 7. Component Architecture

Sigora is structured as a small set of separable runtime components.

### 7.1 Client CLI

Binary: `sigora`

Responsibilities:

- discover the local runtime
- initiate pairing
- request token or access material
- persist local pairing and session state
- avoid storing long-lived provider credentials

Primary commands:

- `sigora pair`
- `sigora token`

### 7.2 Runtime API Server

Binary surface: `sigorad`

Responsibilities:

- expose local API endpoints
- authenticate agent requests
- coordinate policy, approval, storage, and audit
- serve as the central orchestration point for runtime flows

Transport options for v1:

- Unix domain socket
- localhost HTTP

### 7.3 Policy Engine

Responsibilities:

- evaluate requests against allow and deny rules
- default to deny
- optionally mark requests as requiring user approval

Initial v1 inputs:

- `agent_id`
- `provider`
- `action`
- `resource`
- `type`
- `alias`

Output decisions:

- `allow`
- `deny`
- `challenge`

### 7.4 Approval Manager

Responsibilities:

- queue pending pair and token requests
- present them to the local user
- enforce timeout behavior
- trigger macOS system authentication for sensitive approval paths

### 7.5 Credential Manager

Responsibilities:

- import credentials
- resolve provider/type/alias to a stored secret
- read raw secret values from Keychain only when needed
- prevent secret leakage into logs or metadata stores

### 7.6 Session Manager

Responsibilities:

- create session IDs and secret session keys
- persist only hashed session material on the server side
- validate TTL, timestamp skew, and nonce usage
- support manual revocation

### 7.7 Audit Logger

Responsibilities:

- record lifecycle and access events
- provide enough decision context for inspection
- avoid logging raw secrets, session keys, or full credential values

### 7.8 macOS UI

Binary surface: menu bar app under `sigorad`

Responsibilities:

- show runtime health
- display pending pair and token approvals
- support credential import
- show recent logs and managed credential metadata

## 8. Data Architecture

### 8.1 Storage Split

Sigora uses a split-storage model:

- SQLite for metadata, state, and audit
- Keychain for actual secret material

This separation is essential. SQLite is queryable and operationally convenient, but raw secrets must not be stored there.

### 8.2 Main Data Objects

#### Pairings

- `client_id`
- `device_name`
- `paired_at`
- `revoked_at`

#### Sessions

- `session_id`
- `client_id`
- `session_key_hash`
- `expire_at`
- `last_nonce`
- `created_at`

#### Credentials

- `provider`
- `type`
- `alias`
- `ref`
- `updated`
- `expire`

Recommended key:

```text
UNIQUE(provider, type, alias)
```

#### Audit Events

- `time`
- `actor`
- `event_type`
- `decision`
- `reason`
- request metadata

## 9. Protocol Architecture

### 9.1 Pair Flow

The pair flow establishes trust and returns a short-lived session.

```text
sigora pair
  -> runtime receives pair request
  -> runtime creates pending approval
  -> UI presents caller details
  -> user approves or denies
  -> runtime creates session
  -> client stores session locally
```

Representative request fields:

- `client_id`
- `client_name`
- `device_name`
- `user_hint`
- `client_pubkey_fingerprint`
- `request_origin`
- `pair_timeout_sec`

Representative success response:

- `session_id`
- `session_key`
- `expire_at`

### 9.2 Token Flow

The token flow returns provider-compatible access material in v1.

```text
sigora token
  -> client loads local session
  -> client signs request with session key
  -> runtime validates session and replay constraints
  -> runtime checks policy
  -> runtime optionally requires approval
  -> runtime resolves credential reference
  -> runtime reads Keychain secret
  -> runtime returns text/plain value
```

Representative request fields:

- `session_id`
- `provider`
- `type`
- `alias`
- `ts`
- `nonce`
- `mac`

Canonical MAC input:

```text
session_id|provider|type|alias|ts|nonce
```

Response shape:

- `text/plain`
- body contains only the raw value

### 9.3 Future Invocation Flow

The long-term protocol replaces `token` release with proof issuance:

```text
agent
  -> invocation request
  -> policy evaluation
  -> optional user challenge
  -> proof signing
  -> provider-side proof verification
```

This removes the need to export bearer credentials for many integrations.

## 10. Security Architecture

### 10.1 Security Properties

- default deny
- least privilege by action and resource
- short-lived sessions
- replay resistance using timestamp and nonce
- secret containment in Keychain
- no plaintext credential values in logs
- revocable sessions and grants

### 10.2 Threat Model

Sigora is designed against the following common failures:

- agent memory or filesystem leakage
- accidental token persistence in shell history or local config
- replay of a previously observed request
- unauthorized use of an active but expired session
- ambiguous approval when multiple agents or devices are present

### 10.3 Key Security Controls

#### Session Authentication

- session key generated by runtime
- only hash stored server-side
- HMAC-based request authentication in v1

#### Replay Protection

- timestamp skew validation
- per-session nonce tracking

#### Approval Hardening

- pair and high-risk token requests can require interactive approval
- approval must trigger macOS LocalAuthentication

#### Secret Handling

- import values accepted via UI or `stdin`
- no `--value` plaintext CLI argument
- no full secret display in UI

## 11. Deployment Model

### 11.1 V1 Deployment

Current target:

- local macOS runtime
- menu bar UI
- local storage
- local API endpoint

This keeps the trust boundary user-controlled and reduces initial operational complexity.

### 11.2 Future Deployment Modes

- remote Sigora runtime over HTTPS + mTLS
- hardware-backed signer runtime
- provider-integrated proof verification service

These are extensions of the same control-plane model, not separate products.

## 12. Rust Codebase Mapping

Suggested crate layout:

```text
crates/
  sigora-cli/
  sigorad-server/
  sigorad-ui-macos/
  sigora-proto/
  sigora-crypto/
  sigora-store/
```

Mapping:

- `sigora-cli`: local client experience
- `sigorad-server`: runtime orchestration and API
- `sigorad-ui-macos`: user approval and import UX
- `sigora-proto`: shared API and model contracts
- `sigora-crypto`: HMAC and freshness validation
- `sigora-store`: SQLite and Keychain integration

## 13. V1 To V2 Evolution

### 13.1 V1

Primary value:

- controlled local runtime
- auditable secret brokering
- user approval for sensitive requests
- compatibility with existing providers

Key compromise:

- a provider-compatible credential value may still be released to the caller

### 13.2 V2

Primary value:

- proof-based invocation
- provider verification of signed requests
- reduced bearer credential exposure

Migration direction:

1. normalize invocation semantics in the v1 protocol
2. introduce signer-backed proofs alongside credential issuance
3. add provider adapters or native verification support
4. phase out exported bearer credentials where providers support proof verification

## 14. Open Design Decisions

The architecture is stable enough to start implementation, but several choices should be finalized early:

- Unix domain socket vs localhost HTTP as the v1 transport
- exact policy rule format for allow, deny, and challenge decisions
- local configuration format for the client session cache
- nonce retention strategy and cleanup policy
- whether high-risk token requests are policy-driven only or also provider/type driven by default
- how far `sigorad` should bundle daemon, UI, and admin CLI behavior in the first cut

## 15. Implementation Priorities

1. establish the Rust workspace and shared protocol models
2. implement the local runtime, session manager, and audit log
3. implement `pair` and `token` end-to-end
4. add Keychain-backed import and retrieval
5. add menu bar approval flows
6. add revocation, cleanup, and end-to-end tests

## 16. Summary

Sigora is a trust boundary for agent access, not just a token helper.

Its architecture is defined by three principles:

- agents are untrusted by default
- secrets stay in the runtime whenever possible
- authorization and approval are explicit runtime concerns

V1 proves the runtime and control model using existing provider auth systems. V2 extends the same architecture into proof-based invocation, where providers verify signed intent rather than bearer credentials.
