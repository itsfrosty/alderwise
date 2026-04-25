import Foundation
import Testing

@Test
func workspaceLayoutOnlyContainsShellGeometryConstants() throws {
    let source = try sourceText(in: "Sources/AlderwiseApp/WorkspaceLayout.swift")

    #expect(source.contains("analysisPagePickerMinimumWidth") == false)
    #expect(source.contains("analysisPagePickerIdealWidth") == false)
    #expect(source.contains("transactionLedgerHeaderInsets") == false)
    #expect(source.contains("usesPrincipalToolbarPlacement") == false)
}

@Test
func analysisThemeDoesNotExposeToolbarWidthTokens() throws {
    let source = try sourceText(in: "Sources/AlderwiseApp/AnalysisTheme.swift")

    #expect(source.contains("enum Toolbar") == false)
    #expect(source.contains("pagePickerMinimumWidth") == false)
    #expect(source.contains("pagePickerIdealWidth") == false)
}

private func sourceText(in relativePath: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
    let testsDirectory = url.deletingLastPathComponent()
    let packageRoot = testsDirectory
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    return try String(
        contentsOf: packageRoot.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}
