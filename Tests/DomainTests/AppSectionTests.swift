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
func targetsSectionUsesDedicatedDetailView() {
    #expect(AppSection.targets.usesPlaceholderDetailView == false)
    #expect(AppSection.accounts.usesPlaceholderDetailView)
}
