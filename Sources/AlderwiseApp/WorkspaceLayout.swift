import CoreGraphics

enum WorkspaceLayout {
    static let minimumWindowWidth: CGFloat = 1120
    static let minimumWindowHeight: CGFloat = 620

    static let sidebarMinimumWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 220

    static let analysisInspectorMinimumWidth: CGFloat = 280
    static let analysisInspectorIdealWidth: CGFloat = 320
    static let analysisInspectorMaximumWidth: CGFloat = 360
    static let analysisContentCollapsePriority = 0.0
    static let analysisInspectorCollapsePriority = 1.0
}
