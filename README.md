# Sigora

**Sigora** is a Rust implementation of the **Agent Identity Runtime (AIR)** and the reference runtime for the **Agent Invocation Protocol (AIP)**.

Sigora provides a secure runtime for agents and automation tools to access external platforms **without exposing long-lived credentials**.

Instead of distributing API keys or tokens to agents, Sigora acts as a trusted signing runtime.  
Agents request operations, Sigora evaluates policy and generates authenticated requests to providers.

The project introduces a new invocation model:
```
agent → Sigora → provider
```

Sigora becomes the control point for identity, authorization policy, and secure request execution.

## Documentation

This repository currently contains the project definition and implementation plan.

- [Docs Index](./docs/README.md)
- [Architecture Design](./docs/architecture.md)
- [Implementation Strategy](./docs/implementation-strategy.md)
- [Vision And Roadmap](./docs/vision-and-roadmap.md)
- [V1 MVP Spec](./docs/v1-mvp-spec.md)
- [V1 Implementation Notes](./docs/v1-implementation-notes.md)

## Local Validation

- `make check`
- `make e2e`

The shell e2e suite lives in `scripts/e2e` and exercises the Rust `sigora` and `sigorad-server` loop with isolated temporary state.

---

# Core Concepts

## Agent Invocation Protocol (AIP)

**AIP** defines how agents request external operations through Sigora.

Agents send **Invocation Requests** describing:

- provider
- action
- resource
- request parameters

Sigora processes the request and produces a verified invocation toward the provider.

AIP is intentionally minimal and focuses on **secure invocation semantics** rather than credential distribution.

---

## Agent Identity Runtime (AIR)

**AIR** is the runtime architecture implemented by Sigora.

AIR provides:

- identity key management
- request authorization
- invocation signing
- user approval challenges
- audit logging

AIR acts as the **trusted execution layer** between agents and providers.

Agents themselves are treated as **untrusted execution environments**.

---

## Sigora

Sigora is the Rust implementation of AIR.

It provides:

- runtime daemon
- invocation signing engine
- provider compatibility adapters
- policy enforcement system
- identity key management

Sigora is designed to run locally, remotely, or inside dedicated signing environments.

---

# Short-Term Architecture

The short-term goal of Sigora is **practical compatibility with existing platforms**.

Most platforms today rely on credential-based authentication such as:

- OAuth access tokens
- API keys
- cloud IAM session tokens

Sigora integrates with these systems without requiring provider changes.

In this model, Sigora acts as a **credential control runtime**.
```
agent → Sigora → provider adapter → provider
```

Key properties of the short-term model:

- credentials are stored only inside Sigora
- credentials can be issued dynamically per request
- agents never store long-lived secrets
- policy and user approval can be enforced centrally

Sigora can therefore integrate with existing platforms such as:

- GitHub
- AWS
- Kubernetes
- SaaS APIs

without requiring platform modifications.

This compatibility layer allows Sigora to be adopted incrementally.

---

# Identity Model

Sigora operates using **Agent Identities**.

An Agent Identity consists of:

- identity identifier
- public key
- associated provider permissions

Providers associate permissions with an Agent Identity using their existing authorization systems.

Sigora holds the corresponding private key and performs request signing.

---

# Invocation Flow

A typical invocation works as follows:

1. an agent sends an Invocation Request to Sigora
2. Sigora evaluates policy rules
3. Sigora may request user approval
4. Sigora prepares an authenticated request
5. the provider processes the request
6. the result is returned to the agent

Sigora therefore becomes the central authority for **secure agent invocation**.

---

# Security Model

Sigora follows several security principles.

**Credential containment**

Credentials remain inside the runtime and are never distributed to agents.

**Policy enforcement**

All agent requests pass through runtime policy checks.

**Auditable invocation**

Every request can be logged and traced through the runtime.

**User-controlled execution**

Sensitive operations can require interactive user approval.

---

# Long-Term Direction

The long-term goal of the project is to eliminate credential distribution entirely.

Instead of issuing tokens, providers can support **AIP-native invocation verification**.

In this model:
```
agent → Sigora → signed invocation proof → provider
```

Providers verify the invocation proof using the registered Agent Identity public key.

This enables:

- proof-of-possession authentication
- identity-based invocation
- removal of bearer credentials
- stronger protection against credential leakage

The short-term compatibility model allows Sigora to integrate with existing platforms today, while the AIP model provides a path toward a **proof-based invocation ecosystem**.

---

# License

Sigora is licensed under the **Apache License 2.0**.
Agents do not store credentials directly.  
Instead, Sigora obtains or generates credentials when required.
