import Domain
import Testing

@Test
func mappingInferenceFindsDateDescriptionAndAmountColumns() {
    let document = CSVDocument(
        headers: [
            CSVColumn(name: "Posted Date", columnIndex: 0),
            CSVColumn(name: "Merchant", columnIndex: 1),
            CSVColumn(name: "Amount", columnIndex: 2),
        ],
        rows: []
    )

    let mapping = CSVMappingInference().inferMapping(for: document)

    #expect(mapping.dateColumnIndex == 0)
    #expect(mapping.descriptionColumnIndex == 1)
    #expect(mapping.amount == .singleSignedAmount(columnIndex: 2))
}

@Test
func mappingInferenceSupportsDebitAndCreditColumns() {
    let document = CSVDocument(
        headers: [
            CSVColumn(name: "Date", columnIndex: 0),
            CSVColumn(name: "Description", columnIndex: 1),
            CSVColumn(name: "Debit", columnIndex: 4),
            CSVColumn(name: "Credit", columnIndex: 5),
        ],
        rows: []
    )

    let mapping = CSVMappingInference().inferMapping(for: document)

    #expect(mapping.dateColumnIndex == 0)
    #expect(mapping.descriptionColumnIndex == 1)
    #expect(mapping.amount == .debitCredit(debitColumnIndex: 4, creditColumnIndex: 5))
}

@Test
func mappingInferenceRecognizesPostingDateHeader() {
    let document = CSVDocument(
        headers: [
            CSVColumn(name: "Details", columnIndex: 0),
            CSVColumn(name: "Posting Date", columnIndex: 1),
            CSVColumn(name: "Description", columnIndex: 2),
            CSVColumn(name: "Amount", columnIndex: 3),
        ],
        rows: []
    )

    let mapping = CSVMappingInference().inferMapping(for: document)

    #expect(mapping.dateColumnIndex == 1)
    #expect(mapping.descriptionColumnIndex == 2)
    #expect(mapping.amount == .singleSignedAmount(columnIndex: 3))
}
