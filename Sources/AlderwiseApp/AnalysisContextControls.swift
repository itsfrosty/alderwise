import Application
import Domain
import SwiftUI

struct AnalysisContextControls: ToolbarContent {
    struct SelectionBinding<Value> {
        private let getValue: () -> Value
        private let setValue: (Value) -> Void

        init(
            getValue: @escaping () -> Value,
            setValue: @escaping (Value) -> Void
        ) {
            self.getValue = getValue
            self.setValue = setValue
        }

        var wrappedValue: Value {
            get { getValue() }
            nonmutating set { setValue(newValue) }
        }

        var swiftUIBinding: Binding<Value> {
            Binding(
                get: { getValue() },
                set: { setValue($0) }
            )
        }
    }

    enum RangeOption: String, CaseIterable, Equatable, Identifiable, Sendable {
        case monthToDate
        case lastFullMonth
        case yearToDate

        var id: String { rawValue }

        var title: String {
            switch self {
            case .monthToDate:
                "Month to Date"
            case .lastFullMonth:
                "Last Full Month"
            case .yearToDate:
                "Year to Date"
            }
        }

        var analysisRange: AnalysisRange {
            switch self {
            case .monthToDate:
                .monthToDate
            case .lastFullMonth:
                .lastFullMonth
            case .yearToDate:
                .yearToDate
            }
        }

        init?(range: AnalysisRange) {
            switch range {
            case .monthToDate:
                self = .monthToDate
            case .lastFullMonth:
                self = .lastFullMonth
            case .yearToDate:
                self = .yearToDate
            case .custom:
                return nil
            }
        }
    }

    enum ComparisonOption: String, CaseIterable, Equatable, Identifiable, Sendable {
        case previousPeriod
        case samePeriodLastYear
        case none

        var id: String { rawValue }

        var title: String {
            switch self {
            case .previousPeriod:
                "Previous Period"
            case .samePeriodLastYear:
                "Same Period Last Year"
            case .none:
                "None"
            }
        }

        var analysisComparison: AnalysisComparisonMode {
            switch self {
            case .previousPeriod:
                .previousPeriod
            case .samePeriodLastYear:
                .samePeriodLastYear
            case .none:
                AnalysisComparisonMode.none
            }
        }

        init?(comparison: AnalysisComparisonMode) {
            switch comparison {
            case .previousPeriod:
                self = .previousPeriod
            case .samePeriodLastYear:
                self = .samePeriodLastYear
            case .none:
                self = .none
            case .rollingAverage:
                return nil
            }
        }
    }

    nonisolated static let supportedRanges: [RangeOption] = [
        .monthToDate,
        .lastFullMonth,
        .yearToDate,
    ]

    nonisolated static let supportedComparisons: [ComparisonOption] = [
        .previousPeriod,
        .samePeriodLastYear,
        .none,
    ]

    nonisolated static let supportsInteractiveScope = false
    nonisolated static let supportsAdvancedQualifiers = false

    let page: AnalysisPage
    let context: AnalysisContext
    let snapshot: AnalysisSnapshot
    let setRange: (AnalysisRange) -> Void
    let setComparison: (AnalysisComparisonMode) -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup {
            Picker("Range", selection: Self.rangeSelection(
                getContext: { context },
                setRange: setRange
            ).swiftUIBinding) {
                ForEach(Self.supportedRanges) { option in
                    Text(option.title).tag(Optional.some(option))
                }
            }
            .pickerStyle(.menu)

            Picker("Compare", selection: Self.comparisonSelection(
                getContext: { context },
                setComparison: setComparison
            ).swiftUIBinding) {
                ForEach(Self.supportedComparisons) { option in
                    Text(option.title).tag(Optional.some(option))
                }
            }
            .pickerStyle(.menu)

            if let scopeLabel = Self.scopeLabel(
                for: page,
                snapshot: snapshot
            ) {
                HStack(spacing: 6) {
                    Text("Scope")
                        .foregroundStyle(.secondary)
                    Text(scopeLabel)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    nonisolated static func rangeSelection(
        getContext: @escaping () -> AnalysisContext,
        setRange: @escaping (AnalysisRange) -> Void
    ) -> SelectionBinding<RangeOption?> {
        SelectionBinding(
            getValue: {
                RangeOption(range: getContext().range)
            },
            setValue: { option in
                guard let option else {
                    return
                }
                setRange(option.analysisRange)
            }
        )
    }

    nonisolated static func comparisonSelection(
        getContext: @escaping () -> AnalysisContext,
        setComparison: @escaping (AnalysisComparisonMode) -> Void
    ) -> SelectionBinding<ComparisonOption?> {
        SelectionBinding(
            getValue: {
                ComparisonOption(comparison: getContext().comparison)
            },
            setValue: { option in
                guard let option else {
                    return
                }
                setComparison(option.analysisComparison)
            }
        )
    }

    nonisolated static func scopeLabel(
        for page: AnalysisPage,
        snapshot: AnalysisSnapshot
    ) -> String? {
        let context: AnalysisContext?
        switch page {
        case .overview:
            context = snapshot.overview?.context
        case .categories:
            context = snapshot.categories?.context
        case .merchants:
            context = snapshot.merchants?.context
        }

        guard let context else {
            return nil
        }

        return scopeLabel(for: context)
    }

    private nonisolated static func scopeLabel(
        for context: AnalysisContext
    ) -> String {
        return switch context.scope {
        case .workspace:
            basisLabel(for: context.metricBasis)
        case .category:
            "Category"
        case .categoryGroup:
            "Category Group"
        case .merchant:
            "Merchant"
        case .account:
            "Account"
        }
    }

    private nonisolated static func basisLabel(for basis: ReportingExpenseBasis) -> String {
        switch basis {
        case .includedVisibleExpenses:
            "All visible spending"
        case .acceptedExpenses:
            "Accepted spending"
        }
    }
}
