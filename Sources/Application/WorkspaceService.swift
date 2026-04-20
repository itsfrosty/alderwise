import Domain
import CryptoKit
import Foundation

public enum WorkspaceServiceError: Error, Equatable, Sendable {
    case importPreviewNotReady
    case importPreviewSourceRowsUnavailable
    case importPreviewCouldNotNormalizeRow(line: Int)
}

extension WorkspaceServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .importPreviewNotReady:
            "The CSV preview must be valid before it can be imported."
        case .importPreviewSourceRowsUnavailable:
            "The CSV preview no longer has the source rows needed for import."
        case .importPreviewCouldNotNormalizeRow(let line):
            "CSV row \(line) could not be normalized for import."
        }
    }
}

public enum StagedCSVImportOutcome: Equatable, Sendable {
    case staged
    case exactReimportNoOp
}

public struct StagedCSVImportResult: Equatable, Sendable {
    public var outcome: StagedCSVImportOutcome
    public var session: StagedImportSession?
    public var decisions: [ImportRowDecision]
    public var summary: StagedImportDecisionSummary

    public init(
        outcome: StagedCSVImportOutcome,
        session: StagedImportSession?,
        decisions: [ImportRowDecision],
        summary: StagedImportDecisionSummary
    ) {
        self.outcome = outcome
        self.session = session
        self.decisions = decisions
        self.summary = summary
    }
}

public struct WorkspaceService: Sendable {
    private let store: any WorkspaceStoring & StagedImportWriting & ImportDecisionReading
    private let merchantNormalizer: MerchantNormalizer

    public init(
        store: any WorkspaceStoring & StagedImportWriting & ImportDecisionReading,
        merchantNormalizer: MerchantNormalizer = MerchantNormalizer()
    ) {
        self.store = store
        self.merchantNormalizer = merchantNormalizer
    }

    public func loadSnapshot() throws -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            summary: try store.fetchSummary(),
            accounts: try store.fetchAccounts()
        )
    }

    @discardableResult
    public func createAccount(
        named: String,
        kind: AccountKind,
        institutionName: String?
    ) throws -> Account {
        try store.createAccount(
            named: named.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            institutionName: institutionName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }

    public func seedSampleDataIfNeeded() throws {
        let existingAccounts = try store.fetchAccounts()
        guard existingAccounts.isEmpty else {
            return
        }

        _ = try createAccount(
            named: "Checking",
            kind: .checking,
            institutionName: "Local Bank"
        )
        _ = try createAccount(
            named: "Daily Card",
            kind: .creditCard,
            institutionName: "Sample Card"
        )
    }

    @discardableResult
    public func stageCSVImport(
        preview: CSVImportPreview,
        account: Account,
        originalFilename: String,
        csvText: String,
        importedAt: Date = .now
    ) throws -> StagedCSVImportResult {
        guard preview.validation.isReadyForImport else {
            throw WorkspaceServiceError.importPreviewNotReady
        }
        guard preview.sourceRows.count == preview.validation.validRowCount else {
            throw WorkspaceServiceError.importPreviewSourceRowsUnavailable
        }

        let normalizedRows = try preview.sourceRows.map { row in
            try normalizedRow(for: row, mapping: preview.mapping)
        }
        let rowHashes = Set(normalizedRows.map(\.rowHash))
        let existingRowHashes = try store.fetchExistingSourceRowHashes(
            accountID: account.id,
            rowHashes: rowHashes
        )

        if !normalizedRows.isEmpty && existingRowHashes == rowHashes {
            let decisions = normalizedRows.map { _ in
                ImportRowDecision.skippedExactReimport(reason: "Source row already exists for this account.")
            }
            return StagedCSVImportResult(
                outcome: .exactReimportNoOp,
                session: nil,
                decisions: decisions,
                summary: .make(decisions: decisions)
            )
        }

        let duplicateCandidates = try store.fetchLikelyDuplicateTransactions(
            accountID: account.id,
            candidates: normalizedRows.asCandidates
        )
        let duplicateByRowHash = Dictionary(uniqueKeysWithValues: duplicateCandidates.map { ($0.rowHash, $0) })

        let rows = normalizedRows.map { normalizedRow in
            let decision: ImportRowDecision
            if let duplicate = duplicateByRowHash[normalizedRow.rowHash] {
                decision = .flaggedLikelyDuplicate(
                    existingTransactionID: duplicate.existingTransactionID,
                    reason: duplicate.reason
                )
            } else {
                decision = .imported(reason: "New source row.")
            }

            return StagedSourceRowDraft(
                sourceLineNumber: normalizedRow.sourceLineNumber,
                rawPayload: normalizedRow.rawPayload,
                rowHash: normalizedRow.rowHash,
                validationStatus: .valid,
                importDecision: decision
            )
        }
        let decisions = rows.map(\.importDecision)

        let session = try store.createStagedImportSession(
            StagedImportSessionDraft(
                accountID: account.id,
                originalFilename: originalFilename.trimmingCharacters(in: .whitespacesAndNewlines),
                contentHash: Self.sha256Hex(csvText),
                importedAt: importedAt,
                rows: rows,
                mapping: preview.mapping,
                validRowCount: preview.validation.validRowCount,
                invalidRowCount: preview.validation.invalidRowCount,
                status: .staged
            )
        )
        return StagedCSVImportResult(
            outcome: .staged,
            session: session,
            decisions: decisions,
            summary: .make(decisions: decisions)
        )
    }

    public static func rowHash(for row: CSVRow) throws -> String {
        try sha256Hex(rawPayload(for: row))
    }

    private func normalizedRow(
        for row: CSVRow,
        mapping: CSVColumnMapping
    ) throws -> NormalizedImportCandidateWithPayload {
        let rawPayload = try Self.rawPayload(for: row)
        let rowHash = Self.sha256Hex(rawPayload)

        guard
            let transactionDate = dateValue(in: row, at: mapping.dateColumnIndex),
            let description = stringValue(in: row, at: mapping.descriptionColumnIndex),
            let amount = amountValue(in: row, mapping: mapping)
        else {
            throw WorkspaceServiceError.importPreviewCouldNotNormalizeRow(line: row.sourceLineNumber)
        }

        return NormalizedImportCandidateWithPayload(
            rowHash: rowHash,
            sourceLineNumber: row.sourceLineNumber,
            transactionDate: transactionDate,
            rawDescription: description,
            normalizedMerchantName: merchantNormalizer.normalize(description),
            amount: amount,
            rawPayload: rawPayload
        )
    }

    private static func rawPayload(for row: CSVRow) throws -> String {
        let values = row.cells
            .sorted { $0.columnIndex < $1.columnIndex }
            .map(\.value)
        let data = try JSONEncoder().encode(values)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func amountValue(in row: CSVRow, mapping: CSVColumnMapping) -> Decimal? {
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

    private func dateValue(in row: CSVRow, at columnIndex: Int?) -> Date? {
        guard let value = stringValue(in: row, at: columnIndex) else {
            return nil
        }

        for formatter in Self.dateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private func decimalValue(in row: CSVRow, at columnIndex: Int) -> Decimal? {
        guard let value = stringValue(in: row, at: columnIndex) else {
            return nil
        }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func stringValue(in row: CSVRow, at columnIndex: Int?) -> String? {
        guard
            let columnIndex,
            let value = row.cells.first(where: { $0.columnIndex == columnIndex })?.value
        else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static let dateFormatters: [DateFormatter] = [
        makeDateFormatter("yyyy-MM-dd"),
        makeDateFormatter("MM/dd/yyyy"),
        makeDateFormatter("M/d/yyyy"),
    ]

    private static func makeDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private struct NormalizedImportCandidateWithPayload: Equatable, Sendable {
    var rowHash: String
    var sourceLineNumber: Int
    var transactionDate: Date
    var rawDescription: String
    var normalizedMerchantName: String
    var amount: Decimal
    var rawPayload: String
}

extension NormalizedImportCandidateWithPayload {
    var candidate: NormalizedImportCandidate {
        NormalizedImportCandidate(
            rowHash: rowHash,
            sourceLineNumber: sourceLineNumber,
            transactionDate: transactionDate,
            rawDescription: rawDescription,
            normalizedMerchantName: normalizedMerchantName,
            amount: amount
        )
    }
}

private extension Array where Element == NormalizedImportCandidateWithPayload {
    var asCandidates: [NormalizedImportCandidate] {
        map(\.candidate)
    }
}
