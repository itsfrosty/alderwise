import Application
import Domain
import SwiftUI

struct SectionPlaceholderView: View {
    let section: AppSection
    let snapshot: WorkspaceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(section.title)
                .font(.largeTitle.bold())

            if shouldShowEmptyState {
                ContentUnavailableView(
                    section.emptyStateTitle,
                    systemImage: section.systemImage,
                    description: Text(section.emptyStateMessage)
                )
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var shouldShowEmptyState: Bool {
        switch section {
        case .home:
            false
        case .accounts, .transactions, .review, .rules, .targets, .settings:
            true
        }
    }
}
