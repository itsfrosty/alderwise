import Foundation
import Testing

@testable import AlderwiseApp

@Test
func invalidSidebarFrameKeysDetectDetailPaneStartingUnderSidebar() {
    let invalidKey = "NSSplitView Subview Frames main, SidebarNavigationSplitView"
    let domain: [String: Any] = [
        invalidKey: [
            "0.000000, 0.000000, 228.000000, 710.000000, NO, NO",
            "0.000000, 0.000000, 1247.000000, 710.000000, NO, NO",
        ],
        "selectedSidebarSection": "transactions",
    ]

    #expect(NavigationSplitViewStateRepair.invalidSidebarFrameKeys(in: domain) == [invalidKey])
}

@Test
func invalidSidebarFrameKeysIgnoreHealthyAndMalformedValues() {
    let healthyKey = "NSSplitView Subview Frames main, SidebarNavigationSplitView"
    let malformedKey = "NSSplitView Subview Frames other, SidebarNavigationSplitView"
    let domain: [String: Any] = [
        healthyKey: [
            "0.000000, 0.000000, 228.000000, 710.000000, NO, NO",
            "228.000000, 0.000000, 1019.000000, 710.000000, NO, NO",
        ],
        malformedKey: [
            "not-a-frame",
        ],
    ]

    #expect(NavigationSplitViewStateRepair.invalidSidebarFrameKeys(in: domain).isEmpty)
}

@Test
func sanitizedDomainRemovesOnlyInvalidSidebarFrameKeys() {
    let invalidKey = "NSSplitView Subview Frames main, SidebarNavigationSplitView"
    let preservedKey = "selectedSidebarSection"
    let domain: [String: Any] = [
        invalidKey: [
            "0.000000, 0.000000, 228.000000, 710.000000, NO, NO",
            "0.000000, 0.000000, 1247.000000, 710.000000, NO, NO",
        ],
        preservedKey: "transactions",
    ]

    let sanitized = NavigationSplitViewStateRepair.sanitizedDomain(domain)

    #expect(sanitized[invalidKey] == nil)
    #expect(sanitized[preservedKey] as? String == "transactions")
}

@Test
func clearInvalidSidebarFramesSanitizesLegacyAlderwiseDomainWithoutTouchingGlobalDomain() {
    let defaults = UserDefaults(suiteName: #function)!
    defer {
        defaults.removePersistentDomain(forName: #function)
        defaults.removePersistentDomain(forName: "AlderwiseApp")
        defaults.removePersistentDomain(forName: UserDefaults.globalDomain)
    }

    let invalidKey = "NSSplitView Subview Frames main, SidebarNavigationSplitView"
    defaults.set([
        "0.000000, 0.000000, 228.000000, 710.000000, NO, NO",
        "0.000000, 0.000000, 1247.000000, 710.000000, NO, NO",
    ], forKey: invalidKey)
    defaults.setPersistentDomain([
        invalidKey: [
            "0.000000, 0.000000, 228.000000, 710.000000, NO, NO",
            "0.000000, 0.000000, 1247.000000, 710.000000, NO, NO",
        ],
        "selectedSidebarSection": "transactions",
    ], forName: "AlderwiseApp")
    defaults.setPersistentDomain([
        invalidKey: [
            "0.000000, 0.000000, 228.000000, 710.000000, NO, NO",
            "0.000000, 0.000000, 1247.000000, 710.000000, NO, NO",
        ],
        "AppleLanguages": ["en-US"],
    ], forName: UserDefaults.globalDomain)

    NavigationSplitViewStateRepair.clearInvalidSidebarFrames(defaults: defaults)

    #expect(defaults.persistentDomain(forName: #function)?[invalidKey] == nil)
    #expect(defaults.persistentDomain(forName: "AlderwiseApp")?[invalidKey] == nil)
    #expect(defaults.persistentDomain(forName: "AlderwiseApp")?["selectedSidebarSection"] as? String == "transactions")
    #expect(defaults.persistentDomain(forName: UserDefaults.globalDomain)?[invalidKey] != nil)
}
