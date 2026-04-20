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
