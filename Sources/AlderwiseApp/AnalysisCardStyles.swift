import SwiftUI

struct AnalysisMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct AnalysisSelectableRowModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.0001))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.14),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func analysisSelectableRowStyle(isSelected: Bool) -> some View {
        modifier(AnalysisSelectableRowModifier(isSelected: isSelected))
    }
}
