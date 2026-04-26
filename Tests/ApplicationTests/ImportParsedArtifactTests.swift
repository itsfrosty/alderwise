import Application
import Domain
import Testing

@Test
func parsedArtifactPreservesAllParsedRowsWhenInitialPreviewFiltersSomeOut() throws {
    let service = CSVImportPreviewService()
    let artifact = try service.makeParsedArtifact(from: multiShapeGenericCSV())
    let initialPreview = try service.makePreview(from: artifact, mapping: artifact.inferredMapping)
    let recoveredPreview = try service.makePreview(
        from: artifact,
        mapping: alternateShapeMapping()
    )

    #expect(artifact.headers.map(\.name) == [
        "Date",
        "Description",
        "Amount",
        "Posted Date",
        "Merchant",
        "Value",
    ])
    #expect(artifact.rows.map(\.sourceLineNumber) == [2, 3])
    #expect(artifact.profile == .generic)
    #expect(artifact.inferredMapping == CSVColumnMapping(
        dateColumnIndex: 0,
        descriptionColumnIndex: 1,
        amount: .singleSignedAmount(columnIndex: 2)
    ))
    #expect(artifact.rowShapeSummary.normalizedHeaderNames == [
        "date",
        "description",
        "amount",
        "posted date",
        "merchant",
        "value",
    ])
    #expect(artifact.rowShapeSummary.nonBlankColumnIndexesByRow == [
        [0, 1, 2],
        [3, 4, 5],
    ])
    #expect(artifact.mappingShape == ImportMappingShape(
        profile: .generic,
        dateColumnIndex: 0,
        descriptionColumnIndex: 1,
        amountColumnIndexes: [2]
    ))
    #expect(initialPreview.sourceRows.map(\.sourceLineNumber) == [2])
    #expect(recoveredPreview.sourceRows.map(\.sourceLineNumber) == [3])
    #expect(recoveredPreview.previewRows.map(\.interpretedAmount) == [88.10])
}

private func alternateShapeMapping() -> CSVColumnMapping {
    CSVColumnMapping(
        dateColumnIndex: 3,
        descriptionColumnIndex: 4,
        amount: .singleSignedAmount(columnIndex: 5)
    )
}

private func multiShapeGenericCSV() -> String {
    """
    Date,Description,Amount,Posted Date,Merchant,Value
    2026-04-01,Coffee Shop,-4.75,,,
    ,,,2026-04-02,Payroll,88.10
    """
}
