import Foundation

public enum CSVImportProfile: String, Codable, Equatable, Sendable {
    case generic
    case venmoStatement

    public static func infer(from headers: [CSVColumn]) -> CSVImportProfile {
        let normalizedHeaders = headers.map { CSVImportValueParser.normalizedHeaderName($0.name) }
        return normalizedHeaders == venmoStatementHeaderShape ? .venmoStatement : .generic
    }

    public func semantics(
        for row: CSVRow,
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
            let note = row.stringValue(at: venmoStatementColumnIndexes.note)
            let counterparty = venmoCounterparty(in: row, mapping: mapping)
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

    public func semantics(
        for values: [String],
        mapping: CSVColumnMapping
    ) -> CSVImportRowSemantics? {
        switch self {
        case .generic:
            guard let description = stringValue(in: values, at: mapping.descriptionColumnIndex) else {
                return nil
            }
            return CSVImportRowSemantics(
                rawDescription: description,
                derivedMerchant: description,
                categorizationExplanation: nil
            )
        case .venmoStatement:
            let note = stringValue(in: values, at: venmoStatementColumnIndexes.note) ?? ""
            let counterparty = venmoCounterparty(in: values, mapping: mapping)
            let rawDescription = note.isEmpty ? counterparty : note
            let derivedMerchant = counterparty.isEmpty ? rawDescription : counterparty
            guard rawDescription.isEmpty == false, derivedMerchant.isEmpty == false else {
                return nil
            }
            return CSVImportRowSemantics(
                rawDescription: rawDescription,
                derivedMerchant: derivedMerchant,
                categorizationExplanation: "Used for categorization: \(derivedMerchant)"
            )
        }
    }

    private func venmoCounterparty(
        in row: CSVRow,
        mapping: CSVColumnMapping
    ) -> String {
        let from = row.stringValue(at: venmoStatementColumnIndexes.from)
        let to = row.stringValue(at: venmoStatementColumnIndexes.to)
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

    private func venmoCounterparty(
        in values: [String],
        mapping: CSVColumnMapping
    ) -> String {
        let from = stringValue(in: values, at: venmoStatementColumnIndexes.from) ?? ""
        let to = stringValue(in: values, at: venmoStatementColumnIndexes.to) ?? ""
        let amount = amountValue(in: values, mapping: mapping)

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

    private func amountValue(in values: [String], mapping: CSVColumnMapping) -> Decimal? {
        guard let amount = mapping.amount else {
            return nil
        }

        switch amount {
        case .singleSignedAmount(let columnIndex):
            return decimalValue(in: values, at: columnIndex)
        case .debitCredit(let debitColumnIndex, let creditColumnIndex):
            if let debit = decimalValue(in: values, at: debitColumnIndex) {
                return -debit
            }
            return decimalValue(in: values, at: creditColumnIndex)
        }
    }

    private func stringValue(in values: [String], at columnIndex: Int?) -> String? {
        guard
            let columnIndex,
            values.indices.contains(columnIndex)
        else {
            return nil
        }

        let trimmedValue = values[columnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func decimalValue(in values: [String], at columnIndex: Int) -> Decimal? {
        guard values.indices.contains(columnIndex) else {
            return nil
        }

        return CSVImportValueParser.decimal(from: values[columnIndex])
    }
}

private let venmoStatementHeaderShape = [
    "",
    "id",
    "datetime",
    "type",
    "status",
    "note",
    "from",
    "to",
    "amount total",
    "amount tip",
    "amount tax",
    "amount fee",
    "tax rate",
    "tax exempt",
    "funding source",
    "destination",
    "beginning balance",
    "ending balance",
    "statement period venmo fees",
    "terminal location",
    "year to date venmo fees",
    "disclaimer",
]

private let venmoStatementColumnIndexes = (
    note: 5,
    from: 6,
    to: 7
)

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
