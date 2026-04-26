import Foundation

struct AnalysisInspectorDocument: Equatable {
    let title: String
    let sections: [AnalysisInspectorSection]
}

struct AnalysisInspectorSection: Equatable {
    enum Kind: Equatable {
        case summary
        case evidenceKV
        case metricRow
        case bulletList
        case tagList
    }

    let kind: Kind
    let title: String
    let summary: String?
    let keyValues: [AnalysisInspectorKeyValue]
    let metrics: [AnalysisInspectorMetric]
    let bullets: [String]
    let tags: [String]

    static func summary(title: String, text: String) -> AnalysisInspectorSection {
        AnalysisInspectorSection(
            kind: .summary,
            title: title,
            summary: text,
            keyValues: [],
            metrics: [],
            bullets: [],
            tags: []
        )
    }

    static func evidenceKV(title: String, items: [AnalysisInspectorKeyValue]) -> AnalysisInspectorSection {
        AnalysisInspectorSection(
            kind: .evidenceKV,
            title: title,
            summary: nil,
            keyValues: items,
            metrics: [],
            bullets: [],
            tags: []
        )
    }

    static func metricRow(title: String, items: [AnalysisInspectorMetric]) -> AnalysisInspectorSection {
        AnalysisInspectorSection(
            kind: .metricRow,
            title: title,
            summary: nil,
            keyValues: [],
            metrics: items,
            bullets: [],
            tags: []
        )
    }

    static func bulletList(title: String, items: [String]) -> AnalysisInspectorSection {
        AnalysisInspectorSection(
            kind: .bulletList,
            title: title,
            summary: nil,
            keyValues: [],
            metrics: [],
            bullets: items,
            tags: []
        )
    }

    static func tagList(title: String, tags: [String]) -> AnalysisInspectorSection {
        AnalysisInspectorSection(
            kind: .tagList,
            title: title,
            summary: nil,
            keyValues: [],
            metrics: [],
            bullets: [],
            tags: tags
        )
    }
}

struct AnalysisInspectorKeyValue: Equatable {
    let label: String
    let value: String
}

struct AnalysisInspectorMetric: Equatable {
    let label: String
    let value: String
}

func analysisCurrency(_ amount: Decimal) -> String {
    AnalysisCurrencyFormatter.shared.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
}

private enum AnalysisCurrencyFormatter {
    static let shared: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter
    }()
}
