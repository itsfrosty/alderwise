import Domain
import Foundation

public struct CSVImportPreview: Equatable, Sendable {
    public var headers: [CSVColumn]
    public var profile: CSVImportProfile
    public var mapping: CSVColumnMapping
    public var previewRows: [CSVImportPreviewRow]
    public var validation: CSVImportValidationSummary
    public private(set) var sourceRows: [CSVRow]

    private var rowLimit: Int
    public private(set) var parsedArtifact: ImportParsedArtifact?

    public init(
        headers: [CSVColumn],
        profile: CSVImportProfile = .generic,
        mapping: CSVColumnMapping,
        previewRows: [CSVImportPreviewRow],
        validation: CSVImportValidationSummary,
        sourceRows: [CSVRow] = [],
        rowLimit: Int = 10,
        parsedArtifact: ImportParsedArtifact? = nil
    ) {
        self.headers = headers
        self.profile = profile
        self.mapping = mapping
        self.previewRows = previewRows
        self.validation = validation
        self.sourceRows = sourceRows
        self.rowLimit = rowLimit
        self.parsedArtifact = parsedArtifact
    }

    public func applying(mapping newMapping: CSVColumnMapping) -> CSVImportPreview {
        if let parsedArtifact {
            CSVImportPreview.make(
                artifact: parsedArtifact,
                mapping: newMapping,
                rowLimit: rowLimit
            )
        } else {
            CSVImportPreview.make(
                headers: headers,
                profile: profile,
                rows: sourceRows,
                mapping: newMapping,
                rowLimit: rowLimit
            )
        }
    }

    fileprivate static func make(
        headers: [CSVColumn],
        profile: CSVImportProfile,
        rows: [CSVRow],
        mapping: CSVColumnMapping,
        rowLimit: Int
    ) -> CSVImportPreview {
        let effectiveMapping = mapping.withProfile(profile)
        let interpreter = CSVImportRowInterpreter()
        let previewRows = rows.prefix(max(rowLimit, 0)).map { row in
            let semantics = profile.semantics(for: row, mapping: effectiveMapping)
            return CSVImportPreviewRow(
                sourceLineNumber: row.sourceLineNumber,
                cells: row.cells,
                interpretedAmount: interpreter.interpretedAmount(for: row, mapping: effectiveMapping),
                rawDescription: semantics.rawDescription,
                derivedMerchant: semantics.derivedMerchant,
                categorizationExplanation: semantics.categorizationExplanation
            )
        }
        let validation = CSVImportValidationSummary.make(rows: rows, mapping: effectiveMapping)
        let validRowLineNumbers = Set(rows.validSourceRows(mapping: effectiveMapping).map(\.sourceLineNumber))

        return CSVImportPreview(
            headers: headers,
            profile: profile,
            mapping: effectiveMapping,
            previewRows: Array(previewRows),
            validation: validation,
            sourceRows: rows.filter { validRowLineNumbers.contains($0.sourceLineNumber) },
            rowLimit: rowLimit
        )
    }

    fileprivate static func make(
        artifact: ImportParsedArtifact,
        mapping: CSVColumnMapping,
        rowLimit: Int
    ) -> CSVImportPreview {
        let filteredRows = CSVImportPreviewService.filteredRows(artifact.rows, mapping: mapping)
        var preview = CSVImportPreview.make(
            headers: artifact.headers,
            profile: artifact.profile,
            rows: filteredRows,
            mapping: mapping,
            rowLimit: rowLimit
        )
        preview.parsedArtifact = artifact
        return preview
    }
}

public struct CSVImportPreviewRow: Equatable, Sendable {
    public var sourceLineNumber: Int
    public var cells: [CSVCell]
    public var interpretedAmount: Decimal?
    public var rawDescription: String
    public var derivedMerchant: String
    public var categorizationExplanation: String?

    public init(
        sourceLineNumber: Int,
        cells: [CSVCell],
        interpretedAmount: Decimal?,
        rawDescription: String = "",
        derivedMerchant: String = "",
        categorizationExplanation: String? = nil
    ) {
        self.sourceLineNumber = sourceLineNumber
        self.cells = cells
        self.interpretedAmount = interpretedAmount
        self.rawDescription = rawDescription
        self.derivedMerchant = derivedMerchant
        self.categorizationExplanation = categorizationExplanation
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

    public func makeParsedArtifact(from csvText: String) throws -> ImportParsedArtifact {
        let document = try parser.parse(csvText)
        let profile = mappingInference.inferProfile(for: document)
        let inferredMapping = mappingInference.inferMapping(for: document).withProfile(profile)
        return ImportParsedArtifact.make(
            document: document,
            profile: profile,
            inferredMapping: inferredMapping
        )
    }

    public func makePreview(
        from artifact: ImportParsedArtifact,
        mapping: CSVColumnMapping,
        rowLimit: Int = 10
    ) throws -> CSVImportPreview {
        CSVImportPreview.make(artifact: artifact, mapping: mapping, rowLimit: rowLimit)
    }

    public func makePreview(from csvText: String, rowLimit: Int = 10) throws -> CSVImportPreview {
        let artifact = try makeParsedArtifact(from: csvText)
        return try makePreview(
            from: artifact,
            mapping: artifact.inferredMapping,
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

        return CSVImportValueParser.decimal(from: trimmedValue)
    }
}

private extension CSVImportPreviewService {
    static func filteredRows(_ rows: [CSVRow], mapping: CSVColumnMapping) -> [CSVRow] {
        let relevantColumnIndexes = relevantColumnIndexes(for: mapping)
        guard relevantColumnIndexes.isEmpty == false else {
            return rows
        }

        return rows.filter { row in
            relevantColumnIndexes.contains { row.isBlank(columnIndex: $0) == false }
        }
    }

    static func relevantColumnIndexes(for mapping: CSVColumnMapping) -> [Int] {
        var indexes: [Int] = []

        if let dateColumnIndex = mapping.dateColumnIndex {
            indexes.append(dateColumnIndex)
        }
        if let descriptionColumnIndex = mapping.descriptionColumnIndex {
            indexes.append(descriptionColumnIndex)
        }

        switch mapping.amount {
        case .singleSignedAmount(let columnIndex):
            indexes.append(columnIndex)
        case .debitCredit(let debitColumnIndex, let creditColumnIndex):
            indexes.append(debitColumnIndex)
            indexes.append(creditColumnIndex)
        case nil:
            break
        }

        return indexes
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

private extension Array where Element == CSVRow {
    func validSourceRows(mapping: CSVColumnMapping) -> [CSVRow] {
        guard CSVImportRequiredField.missing(from: mapping).isEmpty else {
            return []
        }

        let interpreter = CSVImportRowInterpreter()
        return filter { row in
            row.validationIssues(mapping: mapping, interpreter: interpreter).isEmpty
        }
    }
}
