import SwiftUI

struct DimensionCard: View {
    let title: String
    let estimate: DimensionEstimate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                methodBadge
            }
            Text(estimate.display)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 8) {
                Text(estimate.confidenceDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                toleranceBadge
            }
            Text(String(format: "%.1f mm · %.3f in · %ld pts", estimate.mm, estimate.inches, estimate.pointSupport))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var methodBadge: some View {
        Text(estimate.method.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color(.tertiarySystemBackground), in: Capsule())
    }

    @ViewBuilder private var toleranceBadge: some View {
        if estimate.withinToleranceBand {
            Label("≤ 1/16\"", systemImage: "checkmark.seal.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.green)
        } else {
            Label("> 1/16\"", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
        }
    }
}
