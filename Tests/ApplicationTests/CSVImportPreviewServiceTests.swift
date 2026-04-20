import Application
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
