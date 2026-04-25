import Domain
import Testing

@Test
func homeSectionUsesExpectedNavigationCopy() {
    #expect(AppSection.home.title == "Home")
    #expect(AppSection.home.systemImage == "house")
    #expect(AppSection.home.emptyStateTitle == "Build your local spending workspace")
}

@Test
func reviewSectionExplainsWhenQueueIsEmpty() {
    #expect(AppSection.review.emptyStateTitle == "Everything important has been reviewed")
    #expect(AppSection.review.emptyStateMessage.contains("needs your attention"))
}

@Test
func rulesSectionIsPromotedAheadOfTargetsInSidebarOrder() {
    #expect(
        AppSection.allCases == [
            .home,
            .analysis,
            .transactions,
            .review,
            .rules,
            .targets,
            .accounts,
            .settings,
        ]
    )
    #expect(AppSection.analysis.title == "Analysis")
    #expect(AppSection.analysis.systemImage == "chart.bar.xaxis")
    #expect(AppSection.rules.title == "Rules")
    #expect(AppSection.rules.systemImage == "slider.horizontal.3")
}
