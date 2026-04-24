import Foundation

public struct CSVColumnMapping: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case dateColumnIndex
        case descriptionColumnIndex
        case amount
        case profile
    }

    public var dateColumnIndex: Int?
    public var descriptionColumnIndex: Int?
    public var amount: CSVAmountMapping?
    public var profile: CSVImportProfile

    public init(
        dateColumnIndex: Int?,
        descriptionColumnIndex: Int?,
        amount: CSVAmountMapping?,
        profile: CSVImportProfile = .generic
    ) {
        self.dateColumnIndex = dateColumnIndex
        self.descriptionColumnIndex = descriptionColumnIndex
        self.amount = amount
        self.profile = profile
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateColumnIndex = try container.decodeIfPresent(Int.self, forKey: .dateColumnIndex)
        descriptionColumnIndex = try container.decodeIfPresent(Int.self, forKey: .descriptionColumnIndex)
        amount = try container.decodeIfPresent(CSVAmountMapping.self, forKey: .amount)
        profile = try container.decodeIfPresent(CSVImportProfile.self, forKey: .profile) ?? .generic
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(dateColumnIndex, forKey: .dateColumnIndex)
        try container.encodeIfPresent(descriptionColumnIndex, forKey: .descriptionColumnIndex)
        try container.encodeIfPresent(amount, forKey: .amount)
        try container.encode(profile, forKey: .profile)
    }

    public func withProfile(_ profile: CSVImportProfile) -> CSVColumnMapping {
        CSVColumnMapping(
            dateColumnIndex: dateColumnIndex,
            descriptionColumnIndex: descriptionColumnIndex,
            amount: amount,
            profile: profile
        )
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
