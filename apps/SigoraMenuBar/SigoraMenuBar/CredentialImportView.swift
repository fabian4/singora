import SwiftUI

struct CredentialImportView: View {
    @State private var draft = CredentialImportDraft()
    @State private var secretVisible = false
    @StateObject private var keychain = KeychainBridge()
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Credential Import")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
                Text("Securely import a provider credential into the Sigora runtime.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(SigoraPalette.textSecondary(for: colorScheme))
            }

            SigoraGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    formField(title: "Provider", value: draft.provider)
                    formField(title: "Type", value: draft.credentialType)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            SigoraSectionTitle(title: "Alias")
                            if draft.aliasValid {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(SigoraPalette.success)
                                    .font(.system(size: 12))
                            }
                        }

                        TextField("Alias", text: $draft.alias)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(SigoraPalette.surface(for: colorScheme).opacity(0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        SigoraSectionTitle(title: "Secret Value")
                        HStack {
                            Group {
                                if secretVisible {
                                    TextField("Secret", text: $draft.secret)
                                } else {
                                    SecureField("Secret", text: $draft.secret)
                                }
                            }
                            .textFieldStyle(.plain)
                            .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))

                            Button(secretVisible ? "Hide" : "Show") {
                                secretVisible.toggle()
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(SigoraPalette.primary)
                        }
                        .padding(12)
                        .background(SigoraPalette.surface(for: colorScheme).opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }

            if draft.willOverwrite {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("This alias already exists and will overwrite the stored reference.")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SigoraPalette.warning)
                .padding(12)
                .background(SigoraPalette.warning.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(statusIsError ? SigoraPalette.danger : SigoraPalette.success)
            }

            Text("Secrets are stored in the system Keychain; metadata is stored separately.")
                .font(.system(size: 12))
                .foregroundStyle(SigoraPalette.textSecondary(for: colorScheme))

            HStack(spacing: 10) {
                Button("Import Credential") {
                    importCredential()
                }
                .buttonStyle(SigoraPrimaryButtonStyle())

                Button("Cancel") {
                    draft = CredentialImportDraft()
                    statusMessage = nil
                }
                .buttonStyle(SigoraGhostButtonStyle())
            }

            if !keychain.credentials.isEmpty {
                SigoraGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SigoraSectionTitle(title: "Managed Credentials")
                        ForEach(keychain.credentials.prefix(4)) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(record.provider) / \(record.alias)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
                                    Text(record.credentialType)
                                        .font(.system(size: 11))
                                        .foregroundStyle(SigoraPalette.textSecondary(for: colorScheme))
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 580)
        .background(SigoraPalette.background(for: colorScheme))
        .sigoraPanelBackground()
        .task {
            try? keychain.refresh()
        }
        .onChange(of: draft.alias) { _, newValue in
            draft.aliasValid = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            draft.willOverwrite = keychain.credentials.contains {
                $0.provider == draft.provider &&
                $0.credentialType == draft.credentialType &&
                $0.alias == newValue
            }
        }
    }

    private func formField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SigoraSectionTitle(title: title)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SigoraPalette.surface(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func importCredential() {
        guard draft.aliasValid else {
            statusMessage = "Alias is required."
            statusIsError = true
            return
        }

        guard !draft.secret.isEmpty else {
            statusMessage = "Secret value is required."
            statusIsError = true
            return
        }

        do {
            try keychain.importCredential(
                provider: draft.provider,
                credentialType: draft.credentialType,
                alias: draft.alias,
                secret: draft.secret
            )
            statusMessage = "Credential imported successfully."
            statusIsError = false
            draft.willOverwrite = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }
}
