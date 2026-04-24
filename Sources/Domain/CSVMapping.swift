import Foundation

public struct CSVColumnMapping: Codable, Equatable, Sendable {
    public var dateColumnIndex: Int?
    public var descriptionColumnIndex: Int?
    public var amount: CSVAmountMapping?

    public init(
        dateColumnIndex: Int?,
        descriptionColumnIndex: Int?,
        amount: CSVAmountMapping?
    ) {
        self.dateColumnIndex = dateColumnIndex
        self.descriptionColumnIndex = descriptionColumnIndex
        self.amount = amount
    }
}

public enum CSVAmountMapping: Codable, Equatable, Sendable {
    case singleSignedAmount(columnIndex: Int)
    case debitCredit(debitColumnIndex: Int, creditColumnIndex: Int)
}

public struct CSVMappingInference: Sendable {
    public init() {}

    public func inferMapping(for document: CSVDocument) -> CSVColumnMapping {
        let indexedHeaders = document.headers.map { header in
            IndexedHeader(index: header.columnIndex, normalizedName: CSVImportValueParser.normalizedHeaderName(header.name))
        }

        let dateIndex = firstIndex(
            in: indexedHeaders,
            matching: [
                "date",
                "posted date",
                "posting date",
                "transaction date",
                "trans date",
                "datetime",
            ]
        )

        let descriptionIndex = firstIndex(
            in: indexedHeaders,
            matching: [
                "description",
                "merchant",
                "payee",
                "name",
                "memo",
                "note",
            ]
        )

        let amountIndex = firstIndex(
            in: indexedHeaders,
            matching: [
                "amount",
                "amount total",
                "transaction amount",
                "signed amount",
            ]
        )
        let debitIndex = firstIndex(
            in: indexedHeaders,
            matching: [
                "debit",
                "withdrawal",
                "withdrawals",
                "charge",
            ]
        )
        let creditIndex = firstIndex(
            in: indexedHeaders,
            matching: [
                "credit",
                "deposit",
                "deposits",
                "payment",
            ]
        )

        let amountMapping: CSVAmountMapping?
        if let amountIndex {
            amountMapping = .singleSignedAmount(columnIndex: amountIndex)
        } else if let debitIndex, let creditIndex {
            amountMapping = .debitCredit(debitColumnIndex: debitIndex, creditColumnIndex: creditIndex)
        } else {
            amountMapping = nil
        }

        return CSVColumnMapping(
            dateColumnIndex: dateIndex,
            descriptionColumnIndex: descriptionIndex,
            amount: amountMapping
        )
    }

    public func inferProfile(for document: CSVDocument) -> CSVImportProfile {
        CSVImportProfile.infer(from: document.headers)
    }

    private func firstIndex(in headers: [IndexedHeader], matching candidates: Set<String>) -> Int? {
        headers.first { candidates.contains($0.normalizedName) }?.index
    }
}

private struct IndexedHeader {
    var index: Int
    var normalizedName: String
}
