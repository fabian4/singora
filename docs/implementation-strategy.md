# Sigora Implementation Strategy

## Overview

Sigora v1 should use a mixed implementation model:

- Rust for the security-critical runtime, protocol, storage, and CLI
- Swift for the macOS-native UI and system integrations

This is the most practical architecture for the current product shape.

The core reason is simple:

- Sigora's value is in runtime control, session security, policy, audit, and credential handling, which are strong Rust problems
- the v1 product depends heavily on macOS-native UX and system APIs, which are strong Swift problems

Trying to force all of this into Rust would slow delivery and degrade the quality of the macOS experience.

## Recommended Technology Split

### Rust owns

- pairing and session lifecycle
- token request handling
- policy evaluation
- audit logging
- SQLite metadata storage
- protocol definitions
- CLI implementation
- security-critical request validation

### Swift owns

- menu bar app
- popover and approval dialogs
- credential import UI
- LocalAuthentication
- Keychain integration
- native macOS windowing and interaction details

## Design Principle

Swift should own system UX and system APIs.

Rust should own security decisions and business logic.

That boundary must stay clean. In particular:

- Swift should not decide whether a request is allowed
- Rust should not try to implement native macOS UI behavior
- policy, session validation, and audit logic should not be duplicated across both sides

## Recommended Repository Layout

```text
sigora/
  Cargo.toml
  crates/
    sigora-cli/
    sigorad-core/
    sigorad-server/
    sigora-proto/
    sigora-crypto/
    sigora-store/
  apps/
    SigoraMenuBar/
      SigoraMenuBar.xcodeproj
      SigoraMenuBar/
```

## Rust Components

### `sigora-cli`

Responsibilities:

- implement `sigora pair`
- implement `sigora token`
- discover the local runtime
- persist local session and pairing config

### `sigorad-core`

Responsibilities:

- pairing state machine
- session state machine 1
- token request flow
- policy enforcement
- audit event generation
- revocation and expiry rules

This crate should hold the central business logic and remain UI-independent.

### `sigorad-server`

Responsibilities:

- expose local runtime APIs
- validate and route requests into `sigorad-core`
- coordinate approval and secret lookup workflows

For v1, this should be the Rust daemon process.

### `sigora-proto`

Responsibilities:

- request and response types
- shared enums
- error codes
- API constants

### `sigora-crypto`

Responsibilities:

- HMAC request authentication
- nonce generation and validation
- timestamp window validation

### `sigora-store`

Responsibilities:

- SQLite integration
- session and pairing persistence
- audit persistence
- credential metadata persistence

This crate should store metadata only, not raw credential values.

## Swift Components

### `SigoraMenuBar`

Responsibilities:

- menu bar status item
- runtime popover
- pair approval screens
- token approval screens
- credential import flow
- logs or status windows as needed

### System integrations

Swift should directly use:

- `SwiftUI`
- `AppKit` bridge for status item and popover behavior
- `LocalAuthentication`
- `Security.framework`

## Process Architecture

The recommended v1 process model is:

```text
sigora CLI
   ->
sigorad-server (Rust daemon)
   <-> SQLite
   <-> Swift menu bar app
   <-> Keychain / LocalAuthentication
```

This provides a clear control plane:

- the CLI talks only to the daemon
- the daemon owns state and decisions
- the menu bar app provides native interaction and system access

## Key Boundary Decisions

### Authorization decisions

All final allow or deny decisions should happen in Rust.

That includes:

- session validity
- replay checks
- policy checks
- approval requirements
- revocation checks

Swift should only:

- present the approval UI
- collect user action
- execute system authentication
- report the result back

### Secret access

For v1, Keychain access should live on the Swift side.

Reasoning:

- Keychain and LocalAuthentication are first-class macOS APIs
- this avoids unnecessary FFI complexity in the first implementation
- approval and secret access can stay within the same native integration layer

Even with that choice, Rust must still control whether a secret read is allowed.

The boundary should be:

- Rust says: this request is approved, fetch credential ref `X`
- Swift says: system auth succeeded, Keychain value for ref `X` is available

Rust must never delegate policy to Swift.

## Local Transport Strategy

For v1, prefer:

- `localhost HTTP`

Alternative:

- Unix domain socket

Recommendation:

- start with `localhost HTTP` for speed and easier debugging
- consider Unix domain socket later if the local transport boundary needs to be tightened

The cost of starting with HTTP is low, and it keeps CLI, daemon, and UI integration simple during the early build phase.

## Suggested API Boundaries

### CLI to Rust daemon

- `POST /pair`
- `POST /token`

### Swift UI to Rust daemon

- `GET /ui/pending`
- `POST /ui/approve_pair`
- `POST /ui/deny_pair`
- `POST /ui/approve_token`
- `POST /ui/deny_token`

### Rust daemon to Swift UI

For MVP, use one of:

- polling
- lightweight local notifications

Recommendation:

- start with polling for simplicity

## Why Not Full Rust UI

Using Rust for the macOS UI sounds attractive for language consistency, but it is the wrong tradeoff for v1.

Problems with full Rust UI:

- weaker integration with menu bar and popover conventions
- more friction with `LocalAuthentication`
- more friction with Keychain and other Apple security APIs
- higher risk of building a UI that feels cross-platform instead of native
- slower iteration on approval and import flows

Sigora v1 is a macOS-native product on the server side. The UI should behave like a native macOS security utility.

## Why Not Put Logic In Swift

Putting core runtime logic in Swift would also be a mistake.

Problems with that approach:

- security-sensitive behavior becomes tied to one platform UI layer
- business logic becomes harder to test and reuse
- CLI and daemon behavior drift more easily
- future non-macOS or headless runtime support becomes harder

Rust is the right home for logic that defines the runtime's trust model.

## Recommended Tech Stack

### Rust

- `tokio`
- `axum`
- `serde`
- `rusqlite`
- `tracing`
- `thiserror`
- `anyhow`

### Swift

- `SwiftUI`
- `AppKit`
- `LocalAuthentication`
- `Security.framework`

## Implementation Order

1. Create the Rust workspace and shared protocol crate.
2. Implement `sigorad-core` with basic pair and token flow logic.
3. Implement `sigorad-server` with local HTTP endpoints.
4. Implement `sigora-cli`.
5. Add SQLite-backed storage and audit logging.
6. Create the Swift menu bar app shell.
7. Connect pair approval flow.
8. Connect token approval flow.
9. Add Keychain-backed credential import and retrieval.
10. Add revocation, cleanup, and logs UI.

## Summary

The recommended implementation model for Sigora v1 is:

- Rust daemon
- Rust CLI
- Swift menu bar app

This keeps the architecture honest:

- security and protocol logic live in Rust
- native UI and system integrations live in Swift

That is the cleanest path to a secure and shippable first version.
