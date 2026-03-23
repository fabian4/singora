import SwiftUI

struct ApprovalHeader: View {
    let title: String
    let subtitle: String
    let riskLevel: RiskLevel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(SigoraPalette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            RiskBadge(level: riskLevel)
        }
    }
}
