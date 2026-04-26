import Application
import Domain
import Testing

@Test
func previewServiceParsesCSVAndInfersMapping() throws {
    let csv = """
    Posted Date,Merchant,Amount
    2026-04-01,Coffee Shop,-4.75
    2026-04-02,Payroll,1250.00
    """

    let preview = try CSVImportPreviewService().makePreview(from: csv)

    #expect(preview.headers.map(\.name) == ["Posted Date", "Merchant", "Amount"])
    #expect(preview.mapping.dateColumnIndex == 0)
    #expect(preview.mapping.descriptionColumnIndex == 1)
    #expect(preview.previewRows.map(\.sourceLineNumber) == [2, 3])
    #expect(preview.previewRows.map(\.interpretedAmount) == [-4.75, 1250.00])
}

@Test
func previewServiceInterpretsDebitCreditColumnsAsSignedAmounts() throws {
    let csv = """
    Date,Description,Debit,Credit
    2026-04-01,Coffee Shop,4.75,
    2026-04-02,Payroll,,1250.00
    """

    let preview = try CSVImportPreviewService().makePreview(from: csv)

    #expect(preview.mapping.amount == .debitCredit(debitColumnIndex: 2, creditColumnIndex: 3))
    #expect(preview.previewRows.map(\.interpretedAmount) == [-4.75, 1250.00])
}

@Test
func previewCanApplyUserEditedMapping() throws {
    let csv = """
    When,Details,Value
    2026-04-01,Coffee Shop,-4.75
    """

    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let editedMapping = CSVColumnMapping(
        dateColumnIndex: 0,
        descriptionColumnIndex: 1,
        amount: .singleSignedAmount(columnIndex: 2)
    )
    let remappedPreview = preview.applying(mapping: editedMapping)

    #expect(preview.mapping.dateColumnIndex == nil)
    #expect(remappedPreview.mapping == editedMapping)
    #expect(remappedPreview.previewRows.map(\.interpretedAmount) == [-4.75])
    #expect(remappedPreview.validation.isReadyForImport)
}

@Test
func artifactBackedPreviewCanRecoverRowsAfterRemapping() throws {
    let service = CSVImportPreviewService()
    let artifact = try service.makeParsedArtifact(from: multiShapeGenericCSV())

    let inferredPreview = try service.makePreview(from: artifact, mapping: artifact.inferredMapping)
    let recoveredPreview = try service.makePreview(
        from: artifact,
        mapping: alternateShapeMapping()
    )

    #expect(inferredPreview.sourceRows.map(\.sourceLineNumber) == [2])
    #expect(recoveredPreview.sourceRows.map(\.sourceLineNumber) == [3])
    #expect(recoveredPreview.previewRows.map(\.rawDescription) == ["Payroll"])
    #expect(recoveredPreview.previewRows.map(\.interpretedAmount) == [88.10])
}

@Test
func csvTextPreviewApplyingMappingRecoversRowsFromPreservedArtifact() throws {
    let preview = try CSVImportPreviewService().makePreview(from: multiShapeGenericCSV())
    let remappedPreview = preview.applying(mapping: alternateShapeMapping())

    #expect(preview.parsedArtifact != nil)
    #expect(remappedPreview.sourceRows.map(\.sourceLineNumber) == [3])
    #expect(remappedPreview.previewRows.map(\.rawDescription) == ["Payroll"])
    #expect(remappedPreview.previewRows.map(\.interpretedAmount) == [88.10])
}

@Test
func csvTextWrapperMatchesArtifactBackedPreviewForGenericCSV() throws {
    let service = CSVImportPreviewService()
    let csv = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    2026-04-02,Payroll,1250.00
    """

    let wrapperPreview = try service.makePreview(from: csv)
    let artifact = try service.makeParsedArtifact(from: csv)
    let artifactPreview = try service.makePreview(from: artifact, mapping: artifact.inferredMapping)

    #expect(wrapperPreview == artifactPreview)
    #expect(wrapperPreview.parsedArtifact == artifact)
}

@Test
func csvTextWrapperMatchesArtifactBackedPreviewForKnownProfileCSV() throws {
    let service = CSVImportPreviewService()
    let csv = venmoStatementCSV()

    let wrapperPreview = try service.makePreview(from: csv)
    let artifact = try service.makeParsedArtifact(from: csv)
    let artifactPreview = try service.makePreview(from: artifact, mapping: artifact.inferredMapping)

    #expect(wrapperPreview == artifactPreview)
    #expect(wrapperPreview.parsedArtifact == artifact)
}

@Test
func artifactBackedPreviewsPreserveStagingContractForInitialAndRemappedMappings() throws {
    let service = CSVImportPreviewService()
    let artifact = try service.makeParsedArtifact(from: multiShapeGenericCSV())
    let inferredPreview = try service.makePreview(from: artifact, mapping: artifact.inferredMapping)
    let remappedPreview = try service.makePreview(from: artifact, mapping: alternateShapeMapping())

    #expect(inferredPreview.sourceRows.count == inferredPreview.validation.validRowCount)
    #expect(remappedPreview.sourceRows.count == remappedPreview.validation.validRowCount)
    #expect(remappedPreview.applying(mapping: remappedPreview.mapping).sourceRows.count == remappedPreview.applying(mapping: remappedPreview.mapping).validation.validRowCount)
}

@Test
func previewValidationReportsMissingMappingAndInvalidRows() throws {
    let csv = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    ,Missing Date,10.00
    2026-04-03,Missing Amount,
    """

    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let missingAmountMapping = CSVColumnMapping(
        dateColumnIndex: 0,
        descriptionColumnIndex: 1,
        amount: nil
    )
    let invalidPreview = preview.applying(mapping: missingAmountMapping)

    #expect(invalidPreview.validation.missingRequiredFields == [.amount])
    #expect(invalidPreview.validation.validRowCount == 0)
    #expect(invalidPreview.validation.invalidRowCount == 3)
    #expect(invalidPreview.validation.isReadyForImport == false)

    let restoredPreview = preview.applying(mapping: preview.mapping)

    #expect(restoredPreview.validation.missingRequiredFields.isEmpty)
    #expect(restoredPreview.validation.validRowCount == 1)
    #expect(restoredPreview.validation.invalidRowCount == 2)
    #expect(restoredPreview.validation.rowIssues.map(\.sourceLineNumber) == [3, 4])
}

@Test
func previewServiceHandlesVenmoStatementExports() throws {
    let csv = venmoStatementCSV()

    let preview = try CSVImportPreviewService().makePreview(from: csv)

    #expect(headerName(in: preview, at: preview.mapping.dateColumnIndex) == "Datetime")
    #expect(headerName(in: preview, at: preview.mapping.descriptionColumnIndex) == "Note")
    #expect(amountHeaderName(in: preview) == "Amount (total)")
    #expect(preview.previewRows.map(\.sourceLineNumber) == [5, 6])
    #expect(preview.previewRows.map(\.interpretedAmount) == [-135.00, 42.50])
    #expect(preview.validation.validRowCount == 2)
    #expect(preview.validation.invalidRowCount == 0)
    #expect(preview.validation.isReadyForImport)
}

@Test
func previewServiceDetectsVenmoImportProfileAndShowsDerivedMerchant() throws {
    let preview = try CSVImportPreviewService().makePreview(from: venmoStatementCSV())

    #expect(preview.profile == .venmoStatement)
    #expect(preview.mapping.descriptionColumnIndex == 5)
    #expect(preview.previewRows.map(\.rawDescription) == ["Groceries", "Birthday dinner"])
    #expect(preview.previewRows.map(\.derivedMerchant) == ["Jordan Example", "Taylor Example"])
    #expect(preview.previewRows.map(\.categorizationExplanation) == [
        "Used for categorization: Jordan Example",
        "Used for categorization: Taylor Example",
    ])
}

@Test
func genericCSVImportsStillUseDescriptionColumnDirectly() throws {
    let csv = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    2026-04-02,Payroll,1250.00
    """

    let preview = try CSVImportPreviewService().makePreview(from: csv)

    #expect(preview.profile == .generic)
    #expect(preview.previewRows.map(\.rawDescription) == ["Coffee Shop", "Payroll"])
    #expect(preview.previewRows.map(\.derivedMerchant) == ["Coffee Shop", "Payroll"])
    #expect(preview.previewRows.map(\.categorizationExplanation) == [String?.none, String?.none])
}

@Test
func venmoProfileDetectionRequiresNativeHeaderShape() throws {
    let csv = """
    Datetime,Note,From,To,Amount (total)
    2025-04-05T02:16:52,Groceries,Alex Example,Jordan Example,-135.00
    """

    let preview = try CSVImportPreviewService().makePreview(from: csv)

    #expect(preview.profile == .generic)
    #expect(preview.previewRows.map(\.rawDescription) == ["Groceries"])
    #expect(preview.previewRows.map(\.derivedMerchant) == ["Groceries"])
}

private func headerName(in preview: CSVImportPreview, at columnIndex: Int?) -> String? {
    guard let columnIndex else {
        return nil
    }

    return preview.headers.first { $0.columnIndex == columnIndex }?.name
}

private func amountHeaderName(in preview: CSVImportPreview) -> String? {
    guard case .singleSignedAmount(let columnIndex) = preview.mapping.amount else {
        return nil
    }

    return headerName(in: preview, at: columnIndex)
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

private func venmoStatementCSV() -> String {
    """
    Account Statement - (@alex-example),,,,,,,,,,,,,,,,,,,,,
    Account Activity,,,,,,,,,,,,,,,,,,,,,
    ,ID,Datetime,Type,Status,Note,From,To,Amount (total),Amount (tip),Amount (tax),Amount (fee),Tax Rate,Tax Exempt,Funding Source,Destination,Beginning Balance,Ending Balance,Statement Period Venmo Fees,Terminal Location,Year to Date Venmo Fees,Disclaimer
    ,,,,,,,,,,,,,,,,$7.94,,,,,
    ,4303787187085607348,2025-04-05T02:16:52,Payment,Complete,Groceries,Alex Example,Jordan Example,- $135.00,,0,,0,,Bank Checking *1234,,,,,Venmo,,
    ,4306652244709872490,2025-04-09T01:09:14,Payment,Complete,Birthday dinner,Taylor Example,Alex Example,$42.50,,0,,0,,Venmo balance,,,,,Venmo,,
    ,,,,,,,,,,,,,,,,,$6.94,$0.00,,$0.00,"Disclaimer text"
    """
}
