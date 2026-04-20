import Domain
import CryptoKit
import Foundation

public enum WorkspaceServiceError: Error, Equatable, Sendable {
    case importPreviewNotReady
    case importPreviewSourceRowsUnavailable
}

extension WorkspaceServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .importPreviewNotReady:
            "The CSV preview must be valid before it can be imported."
        case .importPreviewSourceRowsUnavailable:
            "The CSV preview no longer has the source rows needed for import."
        }
    }
}

public struct WorkspaceService: Sendable {
    private let store: any WorkspaceStoring & StagedImportWriting

    public init(store: any WorkspaceStoring & StagedImportWriting) {
        self.store = store
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
    ) throws -> StagedImportSession {
        guard preview.validation.isReadyForImport else {
            throw WorkspaceServiceError.importPreviewNotReady
        }
        guard preview.sourceRows.count == preview.validation.validRowCount else {
            throw WorkspaceServiceError.importPreviewSourceRowsUnavailable
        }

        let rows = try preview.sourceRows.map { row in
            let rawPayload = try Self.rawPayload(for: row)
            return StagedSourceRowDraft(
                sourceLineNumber: row.sourceLineNumber,
                rawPayload: rawPayload,
                rowHash: Self.sha256Hex(rawPayload),
                validationStatus: .valid
            )
        }

        return try store.createStagedImportSession(
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
