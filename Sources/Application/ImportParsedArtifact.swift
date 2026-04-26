import Domain
import Foundation

public struct ImportParsedArtifact: Equatable, Sendable {
    public let headers: [CSVColumn]
    public let rows: [CSVRow]
    public let profile: CSVImportProfile
    public let inferredMapping: CSVColumnMapping
    public let rowShapeSummary: ImportRowShapeSummary
    public let mappingShape: ImportMappingShape

    public init(
        headers: [CSVColumn],
        rows: [CSVRow],
        profile: CSVImportProfile,
        inferredMapping: CSVColumnMapping,
        rowShapeSummary: ImportRowShapeSummary,
        mappingShape: ImportMappingShape
    ) {
        self.headers = headers
        self.rows = rows
        self.profile = profile
        self.inferredMapping = inferredMapping
        self.rowShapeSummary = rowShapeSummary
        self.mappingShape = mappingShape
    }
}

public struct ImportRowShapeSummary: Equatable, Sendable {
    public let normalizedHeaderNames: [String]
    public let nonBlankColumnIndexesByRow: [[Int]]

    public init(
        normalizedHeaderNames: [String],
        nonBlankColumnIndexesByRow: [[Int]]
    ) {
        self.normalizedHeaderNames = normalizedHeaderNames
        self.nonBlankColumnIndexesByRow = nonBlankColumnIndexesByRow
    }
}

public struct ImportMappingShape: Equatable, Sendable {
    public let profile: CSVImportProfile
    public let dateColumnIndex: Int?
    public let descriptionColumnIndex: Int?
    public let amountColumnIndexes: [Int]

    public init(
        profile: CSVImportProfile,
        dateColumnIndex: Int?,
        descriptionColumnIndex: Int?,
        amountColumnIndexes: [Int]
    ) {
        self.profile = profile
        self.dateColumnIndex = dateColumnIndex
        self.descriptionColumnIndex = descriptionColumnIndex
        self.amountColumnIndexes = amountColumnIndexes
    }
}

extension ImportParsedArtifact {
    static func make(document: CSVDocument, profile: CSVImportProfile, inferredMapping: CSVColumnMapping) -> ImportParsedArtifact {
        ImportParsedArtifact(
            headers: document.headers,
            rows: document.rows,
            profile: profile,
            inferredMapping: inferredMapping,
            rowShapeSummary: ImportRowShapeSummary(
                normalizedHeaderNames: document.headers.map { CSVImportValueParser.normalizedHeaderName($0.name) },
                nonBlankColumnIndexesByRow: document.rows.map { row in
                    row.cells.compactMap { cell in
                        cell.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : cell.columnIndex
                    }
                }
            ),
            mappingShape: ImportMappingShape(
                profile: profile,
                dateColumnIndex: inferredMapping.dateColumnIndex,
                descriptionColumnIndex: inferredMapping.descriptionColumnIndex,
                amountColumnIndexes: inferredMapping.amountColumnIndexes
            )
        )
    }
}

private extension CSVColumnMapping {
    var amountColumnIndexes: [Int] {
        switch amount {
        case .singleSignedAmount(let columnIndex):
            [columnIndex]
        case .debitCredit(let debitColumnIndex, let creditColumnIndex):
            [debitColumnIndex, creditColumnIndex]
        case nil:
            []
        }
    }
}
