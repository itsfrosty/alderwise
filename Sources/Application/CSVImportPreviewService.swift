import Domain
import Foundation

public struct CSVImportPreview: Equatable, Sendable {
    public var headers: [CSVColumn]
    public var mapping: CSVColumnMapping
    public var previewRows: [CSVImportPreviewRow]
    public var validation: CSVImportValidationSummary
    public private(set) var sourceRows: [CSVRow]

    private var rowLimit: Int

    public init(
        headers: [CSVColumn],
        mapping: CSVColumnMapping,
        previewRows: [CSVImportPreviewRow],
        validation: CSVImportValidationSummary,
        sourceRows: [CSVRow] = [],
        rowLimit: Int = 10
    ) {
        self.headers = headers
        self.mapping = mapping
        self.previewRows = previewRows
        self.validation = validation
        self.sourceRows = sourceRows
        self.rowLimit = rowLimit
    }

    public func applying(mapping newMapping: CSVColumnMapping) -> CSVImportPreview {
        CSVImportPreview.make(
            headers: headers,
            rows: sourceRows,
            mapping: newMapping,
            rowLimit: rowLimit
        )
    }

    fileprivate static func make(
        headers: [CSVColumn],
        rows: [CSVRow],
        mapping: CSVColumnMapping,
        rowLimit: Int
    ) -> CSVImportPreview {
        let interpreter = CSVImportRowInterpreter()
        let previewRows = rows.prefix(max(rowLimit, 0)).map { row in
            CSVImportPreviewRow(
                sourceLineNumber: row.sourceLineNumber,
                cells: row.cells,
                interpretedAmount: interpreter.interpretedAmount(for: row, mapping: mapping)
            )
        }

        return CSVImportPreview(
            headers: headers,
            mapping: mapping,
            previewRows: Array(previewRows),
            validation: CSVImportValidationSummary.make(rows: rows, mapping: mapping),
            sourceRows: rows,
            rowLimit: rowLimit
        )
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

public struct CSVImportValidationSummary: Equatable, Sendable {
    public var missingRequiredFields: [CSVImportRequiredField]
    public var validRowCount: Int
    public var invalidRowCount: Int
    public var rowIssues: [CSVImportRowIssue]

    public var isReadyForImport: Bool {
        missingRequiredFields.isEmpty && invalidRowCount == 0
    }

    public init(
        missingRequiredFields: [CSVImportRequiredField],
        validRowCount: Int,
        invalidRowCount: Int,
        rowIssues: [CSVImportRowIssue]
    ) {
        self.missingRequiredFields = missingRequiredFields
        self.validRowCount = validRowCount
        self.invalidRowCount = invalidRowCount
        self.rowIssues = rowIssues
    }

    fileprivate static func make(rows: [CSVRow], mapping: CSVColumnMapping) -> CSVImportValidationSummary {
        let missingFields = CSVImportRequiredField.missing(from: mapping)
        let interpreter = CSVImportRowInterpreter()
        let rowIssues = rows.flatMap { row in
            row.validationIssues(mapping: mapping, interpreter: interpreter)
        }
        let invalidRows = Set(rowIssues.map(\.sourceLineNumber)).count

        return CSVImportValidationSummary(
            missingRequiredFields: missingFields,
            validRowCount: missingFields.isEmpty ? rows.count - invalidRows : 0,
            invalidRowCount: missingFields.isEmpty ? invalidRows : rows.count,
            rowIssues: rowIssues
        )
    }
}

public enum CSVImportRequiredField: String, Equatable, Sendable {
    case date
    case description
    case amount

    fileprivate static func missing(from mapping: CSVColumnMapping) -> [CSVImportRequiredField] {
        var missingFields: [CSVImportRequiredField] = []
        if mapping.dateColumnIndex == nil {
            missingFields.append(.date)
        }
        if mapping.descriptionColumnIndex == nil {
            missingFields.append(.description)
        }
        if mapping.amount == nil {
            missingFields.append(.amount)
        }
        return missingFields
    }
}

public struct CSVImportRowIssue: Equatable, Sendable {
    public var sourceLineNumber: Int
    public var field: CSVImportRequiredField
    public var message: String

    public init(sourceLineNumber: Int, field: CSVImportRequiredField, message: String) {
        self.sourceLineNumber = sourceLineNumber
        self.field = field
        self.message = message
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
        return .make(
            headers: document.headers,
            rows: document.rows,
            mapping: mapping,
            rowLimit: rowLimit
        )
    }
}

private struct CSVImportRowInterpreter {
    func interpretedAmount(for row: CSVRow, mapping: CSVColumnMapping) -> Decimal? {
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

private extension CSVRow {
    func validationIssues(
        mapping: CSVColumnMapping,
        interpreter: CSVImportRowInterpreter
    ) -> [CSVImportRowIssue] {
        guard CSVImportRequiredField.missing(from: mapping).isEmpty else {
            return []
        }

        var issues: [CSVImportRowIssue] = []

        if isBlank(columnIndex: mapping.dateColumnIndex) {
            issues.append(
                CSVImportRowIssue(
                    sourceLineNumber: sourceLineNumber,
                    field: .date,
                    message: "Date is required."
                )
            )
        }

        if isBlank(columnIndex: mapping.descriptionColumnIndex) {
            issues.append(
                CSVImportRowIssue(
                    sourceLineNumber: sourceLineNumber,
                    field: .description,
                    message: "Description is required."
                )
            )
        }

        if interpreter.interpretedAmount(for: self, mapping: mapping) == nil {
            issues.append(
                CSVImportRowIssue(
                    sourceLineNumber: sourceLineNumber,
                    field: .amount,
                    message: "Amount is required."
                )
            )
        }

        return issues
    }

    func isBlank(columnIndex: Int?) -> Bool {
        guard let columnIndex,
              let value = cells.first(where: { $0.columnIndex == columnIndex })?.value
        else {
            return true
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
