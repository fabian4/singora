# SigoraMenuBar

This directory is the macOS-native shell for Sigora v1.

## Intended responsibilities

- menu bar status item
- pair approval UI
- token approval UI
- credential import UI
- LocalAuthentication integration
- Keychain integration

## Planned structure

```text
SigoraMenuBar/
  SigoraMenuBar.xcodeproj
  SigoraMenuBar/
    SigoraMenuBarApp.swift
    DesignSystem.swift
    RuntimePanelView.swift
    ApprovalHeader.swift
    PairApprovalView.swift
    TokenApprovalView.swift
    RiskBadge.swift
    Models.swift
    CredentialImportView.swift
    RuntimeAPIClient.swift
    KeychainBridge.swift
```

## Current status

The Xcode project is still intentionally not generated, but the Swift side now has:

- menu bar app entrypoint
- runtime panel view model
- local daemon API client
- pair and token approval cards
- LocalAuthentication service
- Keychain bridge for credential import and lookup
- a `Package.swift` executable target so the app can be opened in Xcode as a Swift package

The current expectation is that the Rust daemon runs on `http://127.0.0.1:8611`.
