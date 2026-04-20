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
