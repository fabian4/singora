import SwiftUI

struct RiskBadge: View {
    let level: RiskLevel

    var body: some View {
        Text(level.rawValue.uppercased())
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor.opacity(0.14))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch level {
        case .low:
            return SigoraPalette.success
        case .medium:
            return SigoraPalette.warning
        case .high:
            return SigoraPalette.danger
        }
    }
}
