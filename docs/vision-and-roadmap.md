# Sigora Vision And Roadmap

## Overview

Sigora is an **Agent Identity Runtime (AIR)** and the reference runtime for the **Agent Invocation Protocol (AIP)**.

Its goal is to move agent access from a credential possession model:

```text
program -> token / API key -> provider
```

to a controlled invocation model:

```text
agent -> Sigora -> provider
```

In this model, the agent does not hold long-lived credentials. Sigora becomes the trust boundary for identity, authorization policy, user approval, and secure request execution.

## Why Sigora Exists

Current agents and automation tools usually rely on bearer credentials:

- API keys
- OAuth access tokens
- cloud IAM session tokens
- session cookies

This creates two structural problems:

- long-lived credentials are copied into untrusted runtimes
- providers often cannot distinguish between a user-approved agent action and raw credential reuse

Sigora addresses this by keeping credentials or signing keys inside a user-controlled runtime and exposing only controlled invocation capability to agents.

## Design Goals

- Credential non-exportability: long-lived secrets stay inside Sigora
- Minimal agent trust: the agent runtime is assumed to be untrusted
- Policy enforcement: every request passes through explicit checks
- User-controlled execution: sensitive actions can require local approval
- Auditability: key actions and decisions are logged
- Incremental adoption: v1 works with existing providers before v2-native verification exists

## System Roles

### User

- owns provider accounts
- deploys and controls Sigora
- approves pairings and sensitive actions

### Agent

- can be an AI agent, CLI tool, automation script, or local assistant
- requests capability from Sigora
- does not persist long-lived platform credentials

### Sigora / AIR

- manages identity keys and sessions
- enforces policy
- handles approval challenges
- retrieves or generates authenticated access
- records audit events

### Provider

- external system such as GitHub, AWS, Kubernetes, or a SaaS API
- in v1 still authenticates using existing credential models
- in v2 can verify invocation proofs directly

## Roadmap

## v1: Compatibility Runtime

The first release is a practical compatibility layer:

```text
agent -> Sigora -> provider adapter -> provider
```

Properties:

- credentials are stored only in Sigora
- agents fetch short-lived or controlled access on demand
- existing provider auth flows remain unchanged
- user approval and policy checks happen centrally

This makes Sigora deployable against current platforms without requiring provider changes.

## v2: Proof-Based Invocation

The longer-term model moves from credential distribution to proof verification:

```text
agent -> Sigora -> signed invocation proof -> provider
```

In that model, the provider verifies:

- identity public key
- signature validity
- action and resource binding
- timestamp and nonce
- provider-side authorization policy

This enables:

- proof-of-possession authentication
- reduced bearer-token exposure
- stronger replay resistance
- identity-native agent invocation

## Core Concepts

### Agent Identity

An identity registered with a provider or trust domain, typically consisting of:

- `identity_id`
- `public_key`

Permissions are bound to this identity through provider-side authorization.

### Pairing

The first trust-establishment flow between an agent and Sigora. Pairing binds a caller identity to the runtime after user approval.

### Session

A short-lived authenticated channel between agent and Sigora, including:

- `session_id`
- expiration
- replay protection metadata

### Invocation Request

A structured request from the agent to perform some provider action, usually including:

- provider
- action
- resource
- operation level
- payload or payload digest

### Invocation Proof

In v2, Sigora signs the invocation so the provider can verify origin, integrity, and freshness without relying on exported bearer credentials.

## Security Principles

- Credential containment: secrets do not leave the runtime unless v1 explicitly returns a compatible value
- Default deny: access is denied unless permitted by policy
- Replay protection: requests are bound to timestamps and nonces
- Action binding: approval and authorization should match specific actions and resources
- Auditability: pair, issue, deny, revoke, expire, and challenge events are tracked

## Repository Direction

This repository should evolve in two layers:

1. A v1 implementation that proves the local runtime, pairing, session, policy, and token-distribution loop.
2. A v2 protocol and verification model that replaces bearer-token distribution with proof-based invocation.
