import Domain
import Foundation

public struct CSVImportPreview: Equatable, Sendable {
    public var headers: [CSVColumn]
    public var mapping: CSVColumnMapping
    public var previewRows: [CSVImportPreviewRow]

    public init(
        headers: [CSVColumn],
        mapping: CSVColumnMapping,
        previewRows: [CSVImportPreviewRow]
    ) {
        self.headers = headers
        self.mapping = mapping
        self.previewRows = previewRows
    }
}

public struct CSVImportPreviewRow: Equatable, Sendable {
    public var sourceLineNumber: Int
    public var cells: [CSVCell]
    public var interpretedAmount: Decimal?

    public init(sourceLineNumber: Int, cells: [CSVCell], interpretedAmount: Decimal?) {
        self.sourceLineNumber = sourceLineNumber
        self.cells = cells
        self.interpretedAmount = interpretedAmount
    }
}

public struct CSVImportPreviewService: Sendable {
    private let parser: CSVParser
    private let mappingInference: CSVMappingInference

    public init(
        parser: CSVParser = CSVParser(),
        mappingInference: CSVMappingInference = CSVMappingInference()
    ) {
        self.parser = parser
        self.mappingInference = mappingInference
    }

    public func makePreview(from csvText: String, rowLimit: Int = 10) throws -> CSVImportPreview {
        let document = try parser.parse(csvText)
        let mapping = mappingInference.inferMapping(for: document)
        let rows = document.rows.prefix(max(rowLimit, 0)).map { row in
            CSVImportPreviewRow(
                sourceLineNumber: row.sourceLineNumber,
                cells: row.cells,
                interpretedAmount: interpretedAmount(for: row, mapping: mapping)
            )
        }

        return CSVImportPreview(
            headers: document.headers,
            mapping: mapping,
            previewRows: Array(rows)
        )
    }

    private func interpretedAmount(for row: CSVRow, mapping: CSVColumnMapping) -> Decimal? {
        guard let amount = mapping.amount else {
            return nil
        }

        switch amount {
        case .singleSignedAmount(let columnIndex):
            return decimalValue(in: row, at: columnIndex)
        case .debitCredit(let debitColumnIndex, let creditColumnIndex):
            if let debit = decimalValue(in: row, at: debitColumnIndex) {
                return -debit
            }
            return decimalValue(in: row, at: creditColumnIndex)
        }
    }

    private func decimalValue(in row: CSVRow, at columnIndex: Int) -> Decimal? {
        guard let cell = row.cells.first(where: { $0.columnIndex == columnIndex }) else {
            return nil
        }

        let trimmedValue = cell.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        return Decimal(string: trimmedValue, locale: Locale(identifier: "en_US_POSIX"))
    }
}
