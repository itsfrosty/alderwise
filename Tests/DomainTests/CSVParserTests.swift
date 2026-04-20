import Domain
import Testing

@Test
func parserPreservesHeadersRowsAndPreviewLocations() throws {
    let csv = #"""
    Date,Description,Amount
    2026-04-01,"Coffee, downtown",-4.75

    2026-04-02,"Book ""Swift Guide""",31.50
    """#

    let document = try CSVParser().parse(csv)

    #expect(document.headers.map(\.name) == ["Date", "Description", "Amount"])
    #expect(document.headers.map(\.columnIndex) == [0, 1, 2])
    #expect(document.rows.count == 2)
    #expect(document.rows.map(\.sourceLineNumber) == [2, 4])
    #expect(document.rows[0].cells.map(\.value) == ["2026-04-01", "Coffee, downtown", "-4.75"])
    #expect(document.rows[1].cells.map(\.value) == ["2026-04-02", "Book \"Swift Guide\"", "31.50"])
    #expect(document.rows[1].cells.map(\.columnIndex) == [0, 1, 2])
}

@Test
func parserRejectsRowsWithWrongColumnCount() throws {
    let csv = """
    Date,Description,Amount
    2026-04-01,Coffee
    """

    #expect(throws: CSVParsingError.self) {
        try CSVParser().parse(csv)
    }
}

@Test
func parserHandlesCRLFTerminatedRows() throws {
    let csv = "Date,Description,Amount\r\n2026-04-01,Coffee,-4.75\r\n2026-04-02,Payroll,1250.00\r\n"

    let document = try CSVParser().parse(csv)

    #expect(document.headers.map(\.name) == ["Date", "Description", "Amount"])
    #expect(document.rows.count == 2)
    #expect(document.rows.map(\.sourceLineNumber) == [2, 3])
}

@Test
func parserAllowsExtraTrailingEmptyFieldsInRows() throws {
    let csv = """
    Details,Posting Date,Description,Amount,Type,Balance,Check or Slip #
    DEBIT,04/17/2026,Payment,-120.00,ACH_DEBIT,72116.52,,
    """

    let document = try CSVParser().parse(csv)

    #expect(document.headers.count == 7)
    #expect(document.rows.count == 1)
    #expect(document.rows[0].cells.count == 7)
    #expect(document.rows[0].cells.map(\.value).suffix(2) == ["72116.52", ""])
}

@Test
func parserAcceptsHeaderOnlyDocuments() throws {
    let csv = "Date,Description,Amount\n"

    let document = try CSVParser().parse(csv)

    #expect(document.headers.map(\.name) == ["Date", "Description", "Amount"])
    #expect(document.rows.isEmpty)
}

@Test
func parserPreservesExtremelyLongFieldValues() throws {
    let description = String(repeating: "Long merchant memo ", count: 600)
    let csv = """
    Date,Description,Amount
    2026-04-01,\(description),-4.75
    """

    let document = try CSVParser().parse(csv)

    #expect(document.rows.count == 1)
    #expect(document.rows[0].cells[1].value == description)
}

@Test
func parsingErrorsDescribeLineAndColumnDetails() {
    let error = CSVParsingError.unexpectedQuote(line: 12, column: 8)

    #expect(error.localizedDescription == "Unexpected quote in CSV at line 12, column 8.")
}
