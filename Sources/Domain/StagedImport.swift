import Foundation

public enum StagedSourceRowValidationStatus: String, Codable, Equatable, Sendable {
    case valid
    case invalid
}

public enum ImportSessionStatus: String, Codable, Equatable, Sendable {
    case staged
    case imported
    case cancelled
}

public struct StagedSourceRowDraft: Equatable, Sendable {
    public var sourceLineNumber: Int
    public var rawPayload: String
    public var rowHash: String
    public var validationStatus: StagedSourceRowValidationStatus
    public var importDecision: ImportRowDecision
    public var classification: TransactionClassificationDecision?
    public var normalizedMerchantName: String?

    public init(
        sourceLineNumber: Int,
        rawPayload: String,
        rowHash: String,
        validationStatus: StagedSourceRowValidationStatus,
        importDecision: ImportRowDecision = .imported(reason: "New source row."),
        classification: TransactionClassificationDecision? = nil,
        normalizedMerchantName: String? = nil
    ) {
        self.sourceLineNumber = sourceLineNumber
        self.rawPayload = rawPayload
        self.rowHash = rowHash
        self.validationStatus = validationStatus
        self.importDecision = importDecision
        self.classification = classification
        self.normalizedMerchantName = normalizedMerchantName
    }
}

public struct StagedImportSessionDraft: Equatable, Sendable {
    public var accountID: UUID
    public var originalFilename: String
    public var contentHash: String
    public var importedAt: Date
    public var rows: [StagedSourceRowDraft]
    public var mapping: CSVColumnMapping
    public var validRowCount: Int
    public var invalidRowCount: Int
    public var status: ImportSessionStatus

    public init(
        accountID: UUID,
        originalFilename: String,
        contentHash: String,
        importedAt: Date,
        rows: [StagedSourceRowDraft],
        mapping: CSVColumnMapping,
        validRowCount: Int,
        invalidRowCount: Int,
        status: ImportSessionStatus
    ) {
        self.accountID = accountID
        self.originalFilename = originalFilename
        self.contentHash = contentHash
        self.importedAt = importedAt
        self.rows = rows
        self.mapping = mapping
        self.validRowCount = validRowCount
        self.invalidRowCount = invalidRowCount
        self.status = status
    }
}

public struct StagedSourceFile: Equatable, Sendable {
    public var id: Int64
    public var accountID: UUID
    public var originalFilename: String
    public var contentHash: String
    public var importedAt: Date
    public var rowCount: Int

    public init(
        id: Int64,
        accountID: UUID,
        originalFilename: String,
        contentHash: String,
        importedAt: Date,
        rowCount: Int
    ) {
        self.id = id
        self.accountID = accountID
        self.originalFilename = originalFilename
        self.contentHash = contentHash
        self.importedAt = importedAt
        self.rowCount = rowCount
    }
}

public struct StagedSourceRow: Equatable, Sendable {
    public var id: Int64
    public var sourceFileID: Int64
    public var sourceLineNumber: Int
    public var rawPayload: String
    public var rowHash: String
    public var validationStatus: StagedSourceRowValidationStatus
    public var importDecision: ImportRowDecision

    public init(
        id: Int64,
        sourceFileID: Int64,
        sourceLineNumber: Int,
        rawPayload: String,
        rowHash: String,
        validationStatus: StagedSourceRowValidationStatus,
        importDecision: ImportRowDecision = .imported(reason: "New source row.")
    ) {
        self.id = id
        self.sourceFileID = sourceFileID
        self.sourceLineNumber = sourceLineNumber
        self.rawPayload = rawPayload
        self.rowHash = rowHash
        self.validationStatus = validationStatus
        self.importDecision = importDecision
    }
}

public struct StagedImportSession: Identifiable, Equatable, Sendable {
    public var id: Int64
    public var sourceFile: StagedSourceFile
    public var mapping: CSVColumnMapping
    public var validRowCount: Int
    public var invalidRowCount: Int
    public var status: ImportSessionStatus
    public var rows: [StagedSourceRow]

    public init(
        id: Int64,
        sourceFile: StagedSourceFile,
        mapping: CSVColumnMapping,
        validRowCount: Int,
        invalidRowCount: Int,
        status: ImportSessionStatus,
        rows: [StagedSourceRow]
    ) {
        self.id = id
        self.sourceFile = sourceFile
        self.mapping = mapping
        self.validRowCount = validRowCount
        self.invalidRowCount = invalidRowCount
        self.status = status
        self.rows = rows
    }
}
