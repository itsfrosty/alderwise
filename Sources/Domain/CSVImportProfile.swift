import Foundation

public enum CSVImportProfile: String, Codable, Equatable, Sendable {
    case generic
    case venmoStatement

    public static func infer(from headers: [CSVColumn]) -> CSVImportProfile {
        let normalizedHeaders = Set(headers.map { CSVImportValueParser.normalizedHeaderName($0.name) })
        let venmoHeaders: Set<String> = [
            "datetime",
            "note",
            "from",
            "to",
            "amount total",
        ]

        return venmoHeaders.isSubset(of: normalizedHeaders) ? .venmoStatement : .generic
    }

    public func semantics(
        for row: CSVRow,
        headers: [CSVColumn],
        mapping: CSVColumnMapping
    ) -> CSVImportRowSemantics {
        switch self {
        case .generic:
            let description = row.stringValue(at: mapping.descriptionColumnIndex)
            return CSVImportRowSemantics(
                rawDescription: description,
                derivedMerchant: description,
                categorizationExplanation: nil
            )
        case .venmoStatement:
            let note = row.stringValue(at: mapping.descriptionColumnIndex)
            let counterparty = venmoCounterparty(in: row, headers: headers, mapping: mapping)
            let rawDescription = note.isEmpty ? counterparty : note
            let derivedMerchant = counterparty.isEmpty ? rawDescription : counterparty

            return CSVImportRowSemantics(
                rawDescription: rawDescription,
                derivedMerchant: derivedMerchant,
                categorizationExplanation: derivedMerchant.isEmpty
                    ? nil
                    : "Used for categorization: \(derivedMerchant)"
            )
        }
    }

    public var previewGuidanceText: String? {
        switch self {
        case .generic:
            nil
        case .venmoStatement:
            "Venmo imports keep the Note column as the raw description."
        }
    }

    private func venmoCounterparty(
        in row: CSVRow,
        headers: [CSVColumn],
        mapping: CSVColumnMapping
    ) -> String {
        let from = row.stringValue(at: indexOfHeader(named: "From", in: headers))
        let to = row.stringValue(at: indexOfHeader(named: "To", in: headers))
        let amount = amountValue(in: row, mapping: mapping)

        if let amount {
            if amount < 0 {
                return to.isEmpty ? from : to
            }
            if amount > 0 {
                return from.isEmpty ? to : from
            }
        }

        return to.isEmpty ? from : to
    }

    private func indexOfHeader(named name: String, in headers: [CSVColumn]) -> Int? {
        let normalizedName = CSVImportValueParser.normalizedHeaderName(name)
        return headers.first {
            CSVImportValueParser.normalizedHeaderName($0.name) == normalizedName
        }?.columnIndex
    }

    private func amountValue(in row: CSVRow, mapping: CSVColumnMapping) -> Decimal? {
        guard let amount = mapping.amount else {
            return nil
        }

        switch amount {
        case .singleSignedAmount(let columnIndex):
            return row.decimalValue(at: columnIndex)
        case .debitCredit(let debitColumnIndex, let creditColumnIndex):
            if let debit = row.decimalValue(at: debitColumnIndex) {
                return -debit
            }
            return row.decimalValue(at: creditColumnIndex)
        }
    }
}

public struct CSVImportRowSemantics: Equatable, Sendable {
    public var rawDescription: String
    public var derivedMerchant: String
    public var categorizationExplanation: String?

    public init(
        rawDescription: String,
        derivedMerchant: String,
        categorizationExplanation: String?
    ) {
        self.rawDescription = rawDescription
        self.derivedMerchant = derivedMerchant
        self.categorizationExplanation = categorizationExplanation
    }
}

private extension CSVRow {
    func stringValue(at columnIndex: Int?) -> String {
        guard let columnIndex else {
            return ""
        }

        return cells
            .first(where: { $0.columnIndex == columnIndex })?
            .value
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func decimalValue(at columnIndex: Int) -> Decimal? {
        guard let cell = cells.first(where: { $0.columnIndex == columnIndex }) else {
            return nil
        }

        return CSVImportValueParser.decimal(from: cell.value)
    }
}
