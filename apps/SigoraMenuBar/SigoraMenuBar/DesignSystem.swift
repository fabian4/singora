import SwiftUI

enum SigoraPalette {
    static func background(for scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(red: 0.10, green: 0.11, blue: 0.14)
        default:
            return Color(red: 0.975, green: 0.976, blue: 0.995)
        }
    }

    static func surface(for scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(red: 0.18, green: 0.19, blue: 0.24).opacity(0.70)
        default:
            return Color.white.opacity(0.68)
        }
    }

    static func surfaceHigh(for scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(red: 0.20, green: 0.21, blue: 0.27).opacity(0.84)
        default:
            return Color.white.opacity(0.82)
        }
    }

    static func surfaceHighest(for scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(red: 0.24, green: 0.25, blue: 0.31).opacity(0.90)
        default:
            return Color(red: 0.93, green: 0.93, blue: 0.95).opacity(0.92)
        }
    }

    static let primary = Color(red: 0.35, green: 0.34, blue: 0.84)
    static let primaryDeep = Color(red: 0.25, green: 0.23, blue: 0.74)
    static let success = Color(red: 0.22, green: 0.72, blue: 0.32)
    static let warning = Color(red: 0.49, green: 0.24, blue: 0.00)
    static let danger = Color(red: 0.73, green: 0.10, blue: 0.10)

    static func textPrimary(for scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(red: 0.93, green: 0.94, blue: 0.96)
        default:
            return Color(red: 0.10, green: 0.11, blue: 0.12)
        }
    }

    static func textSecondary(for scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(red: 0.75, green: 0.77, blue: 0.82)
        default:
            return Color(red: 0.27, green: 0.27, blue: 0.33)
        }
    }

    static func outline(for scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color.white.opacity(0.14)
        default:
            return Color(red: 0.78, green: 0.77, blue: 0.84).opacity(0.35)
        }
    }

    static let shadow = Color.black.opacity(0.08)
}

struct SigoraPanelBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.10 : 0.78),
                        SigoraPalette.surfaceHighest(for: colorScheme).opacity(0.90),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(SigoraPalette.outline(for: colorScheme), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: SigoraPalette.shadow, radius: 30, x: 0, y: 12)
    }
}

extension View {
    func sigoraPanelBackground() -> some View {
        modifier(SigoraPanelBackground())
    }
}

struct SigoraSectionTitle: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .tracking(1.1)
            .foregroundStyle(SigoraPalette.textSecondary(for: colorScheme))
    }
}

struct SigoraGlassCard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SigoraPalette.surfaceHigh(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SigoraPalette.outline(for: colorScheme), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SigoraPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                LinearGradient(
                    colors: [SigoraPalette.primary, SigoraPalette.primaryDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(configuration.isPressed ? 0.75 : 1)
            )
            .clipShape(Capsule())
    }
}

struct SigoraGhostButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(SigoraPalette.surface(for: colorScheme).opacity(configuration.isPressed ? 0.95 : 0.72))
            .overlay(
                Capsule()
                    .stroke(SigoraPalette.outline(for: colorScheme), lineWidth: 0.8)
            )
            .clipShape(Capsule())
    }
}
