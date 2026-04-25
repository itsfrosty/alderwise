import SwiftUI

enum AnalysisTheme {
    enum SectionSpacing {
        static let group: CGFloat = 24
        static let content: CGFloat = 16
    }

    enum Card {
        static let cornerRadius: CGFloat = 18
        static let contentPadding: CGFloat = 20
        static let contentSpacing: CGFloat = 16
    }

    enum MetricTypography {
        static let valueFont: Font = .system(.title3, design: .rounded).weight(.semibold)
        static let detailFont: Font = .subheadline
        static let labelFont: Font = .caption
    }

    enum Badge {
        static let cornerRadius: CGFloat = 10
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 6
        static let spacing: CGFloat = 6
    }
}

struct AnalysisCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AnalysisTheme.Card.contentPadding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AnalysisTheme.Card.cornerRadius, style: .continuous))
    }
}

struct AnalysisBadgeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AnalysisTheme.MetricTypography.labelFont.weight(.semibold))
            .padding(.horizontal, AnalysisTheme.Badge.horizontalPadding)
            .padding(.vertical, AnalysisTheme.Badge.verticalPadding)
            .background(.quinary, in: Capsule())
    }
}

struct AnalysisMetricValueModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AnalysisTheme.MetricTypography.valueFont)
            .monospacedDigit()
    }
}

extension View {
    func analysisSharedCardStyle() -> some View {
        modifier(AnalysisCardModifier())
    }

    func analysisSharedBadgeStyle() -> some View {
        modifier(AnalysisBadgeModifier())
    }

    func analysisSharedMetricValueStyle() -> some View {
        modifier(AnalysisMetricValueModifier())
    }
}
