import Foundation

public struct CSVDocument: Equatable, Sendable {
    public var headers: [CSVColumn]
    public var rows: [CSVRow]

    public init(headers: [CSVColumn], rows: [CSVRow]) {
        self.headers = headers
        self.rows = rows
    }
}

public struct CSVColumn: Equatable, Sendable {
    public var name: String
    public var columnIndex: Int

    public init(name: String, columnIndex: Int) {
        self.name = name
        self.columnIndex = columnIndex
    }
}

public struct CSVRow: Equatable, Sendable {
    public var sourceLineNumber: Int
    public var cells: [CSVCell]

    public init(sourceLineNumber: Int, cells: [CSVCell]) {
        self.sourceLineNumber = sourceLineNumber
        self.cells = cells
    }
}

public struct CSVCell: Equatable, Sendable {
    public var value: String
    public var columnIndex: Int

    public init(value: String, columnIndex: Int) {
        self.value = value
        self.columnIndex = columnIndex
    }
}

public enum CSVParsingError: Error, Equatable, Sendable {
    case emptyDocument
    case unterminatedQuotedField(line: Int)
    case unexpectedQuote(line: Int, column: Int)
    case wrongColumnCount(line: Int, expected: Int, actual: Int)
}

public struct CSVParser: Sendable {
    public init() {}

    public func parse(_ text: String) throws -> CSVDocument {
        let records = try records(from: text)
        guard let headerRecord = records.first else {
            throw CSVParsingError.emptyDocument
        }

        let headers = headerRecord.fields.enumerated().map { index, name in
            CSVColumn(name: name, columnIndex: index)
        }

        let rows = try records.dropFirst().map { record in
            let fields = record.fields.trimmingEmptySuffix(toCount: headers.count)
            guard fields.count == headers.count else {
                throw CSVParsingError.wrongColumnCount(
                    line: record.lineNumber,
                    expected: headers.count,
                    actual: record.fields.count
                )
            }

            return CSVRow(
                sourceLineNumber: record.lineNumber,
                cells: fields.enumerated().map { index, value in
                    CSVCell(value: value, columnIndex: index)
                }
            )
        }

        return CSVDocument(headers: headers, rows: rows)
    }

    private func records(from text: String) throws -> [CSVRecord] {
        var records: [CSVRecord] = []
        var fields: [String] = []
        var field = ""
        var lineNumber = 1
        var recordStartLine = 1
        var columnNumber = 1
        var isQuoted = false
        var justClosedQuote = false
        var hasRecordContent = false

        let scalars = Array(text)
        var index = scalars.startIndex

        func appendField() {
            fields.append(field)
            field = ""
            justClosedQuote = false
        }

        func appendRecordIfNeeded() {
            guard hasRecordContent || !fields.isEmpty || !field.isEmpty else {
                return
            }
            appendField()
            let isBlank = fields.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if !isBlank {
                records.append(CSVRecord(lineNumber: recordStartLine, fields: fields))
            }
            fields = []
            hasRecordContent = false
            recordStartLine = lineNumber + 1
        }

        while index < scalars.endIndex {
            let character = scalars[index]

            if isQuoted {
                if character == "\"" {
                    let nextIndex = scalars.index(after: index)
                    if nextIndex < scalars.endIndex, scalars[nextIndex] == "\"" {
                        field.append("\"")
                        index = nextIndex
                        columnNumber += 1
                    } else {
                        isQuoted = false
                        justClosedQuote = true
                    }
                } else {
                    field.append(character)
                }

                if character.isCSVLineBreak {
                    lineNumber += 1
                    columnNumber = 0
                }

                index = scalars.index(after: index)
                columnNumber += 1
                continue
            }

            switch character {
            case "\"":
                if field.isEmpty {
                    isQuoted = true
                    hasRecordContent = true
                } else {
                    throw CSVParsingError.unexpectedQuote(line: lineNumber, column: columnNumber)
                }
            case ",":
                appendField()
                hasRecordContent = true
            case _ where character.isCSVLineBreak:
                appendRecordIfNeeded()
                lineNumber += 1
                columnNumber = 0
                recordStartLine = lineNumber
            default:
                if justClosedQuote, !character.isWhitespace {
                    throw CSVParsingError.unexpectedQuote(line: lineNumber, column: columnNumber)
                }
                field.append(character)
                hasRecordContent = true
            }

            index = scalars.index(after: index)
            columnNumber += 1
        }

        guard !isQuoted else {
            throw CSVParsingError.unterminatedQuotedField(line: recordStartLine)
        }

        appendRecordIfNeeded()
        return records
    }
}

private struct CSVRecord {
    var lineNumber: Int
    var fields: [String]
}

private extension Array where Element == String {
    func trimmingEmptySuffix(toCount count: Int) -> [String] {
        guard self.count > count else {
            return self
        }

        let extraFields = suffix(self.count - count)
        guard extraFields.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return self
        }

        return Array(prefix(count))
    }
}

private extension Character {
    var isCSVLineBreak: Bool {
        self == "\n" || self == "\r" || self == "\r\n"
    }
}
