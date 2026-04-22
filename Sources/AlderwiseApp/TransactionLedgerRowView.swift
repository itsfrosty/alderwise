import Domain
import SwiftUI

extension TransactionLedgerView {
    struct Row: View {
        let transaction: TransactionLedgerRow

        var body: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(transaction.merchantName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(transaction.rawDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(amountText)
                        .font(.headline)
                    Text(transaction.transactionDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 5)
        }

        private var amountText: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
            return formatter.string(from: NSDecimalNumber(decimal: transaction.amount)) ?? "\(transaction.amount)"
        }
    }
}
