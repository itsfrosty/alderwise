import Domain
import Foundation

public enum ImportResultMessage {
    public static func make(
        for outcome: StagedCSVImportOutcome,
        summary: StagedImportDecisionSummary
    ) -> String {
        switch outcome {
        case .staged:
            "\(summary.importedRowCount) imported to Transactions, \(summary.skippedRowCount) skipped, \(summary.pendingClassificationReviewRowCount) sent to Review, \(summary.flaggedDuplicateRowCount) likely duplicates waiting in Review."
        case .exactReimportNoOp:
            "\(summary.skippedRowCount) rows already imported. No changes made."
        }
    }
}
