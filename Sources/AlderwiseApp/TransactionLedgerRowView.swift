import Domain
import SwiftUI

extension TransactionLedgerView {
    struct Row: View {
        let transaction: TransactionLedgerRow

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(merchantText)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(amountText)
                        .font(.headline)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if !badgeDescriptors.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(badgeDescriptors, id: \.text) { descriptor in
                                badge(text: descriptor.text, color: descriptor.color)
                            }
                        }
                    }
                }

                if let tertiaryDescriptionText {
                    Text(tertiaryDescriptionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 6)
        }

        private var amountText: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
            return formatter.string(from: NSDecimalNumber(decimal: transaction.amount)) ?? "\(transaction.amount)"
        }

        private var merchantText: String {
            normalized(transaction.merchantName) ?? normalized(transaction.rawDescription) ?? "Unknown Merchant"
        }

        private var metadataText: String {
            [
                categoryText,
                normalized(transaction.accountName) ?? "Unknown Account",
                transaction.transactionDate.formatted(date: .abbreviated, time: .omitted),
            ]
            .joined(separator: " · ")
        }

        private var categoryText: String {
            normalized(transaction.categoryName) ?? "Uncategorized"
        }

        private var tertiaryDescriptionText: String? {
            guard let description = normalized(transaction.rawDescription) else {
                return nil
            }
            return description == merchantText ? nil : description
        }

        private var badgeDescriptors: [(text: String, color: Color)] {
            var badges: [(text: String, color: Color)] = []

            if transaction.isHidden {
                badges.append(("Hidden", .secondary))
            }

            switch transaction.reviewStatus {
            case .pending:
                badges.append(("Needs Review", .orange))
            case .rejected:
                badges.append(("Rejected", .red))
            case .accepted:
                break
            }

            return badges
        }

        private func badge(text: String, color: Color) -> some View {
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.12), in: Capsule())
        }

        private func normalized(_ text: String?) -> String? {
            guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return nil
            }
            return text
        }
    }
}
