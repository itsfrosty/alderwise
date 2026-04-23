import Foundation

public enum RecurringChargeCadence: String, Equatable, Sendable {
    case monthly
    case quarterly
    case annual
}

public struct RecurringChargeAmountRange: Equatable, Sendable {
    public var minimum: Decimal
    public var maximum: Decimal

    public init(minimum: Decimal, maximum: Decimal) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public struct RecurringChargeInsightDetail: Equatable, Sendable {
    public var accountID: UUID
    public var normalizedMerchantName: String
    public var cadence: RecurringChargeCadence
    public var observationCount: Int
    public var amountRange: RecurringChargeAmountRange
    public var supportingTransactionIDs: [UUID]
    public var lastObservedDate: Date
    public var nextExpectedDateWindow: DateInterval?

    public init(
        accountID: UUID,
        normalizedMerchantName: String,
        cadence: RecurringChargeCadence,
        observationCount: Int,
        amountRange: RecurringChargeAmountRange,
        supportingTransactionIDs: [UUID],
        lastObservedDate: Date,
        nextExpectedDateWindow: DateInterval?
    ) {
        self.accountID = accountID
        self.normalizedMerchantName = normalizedMerchantName
        self.cadence = cadence
        self.observationCount = observationCount
        self.amountRange = amountRange
        self.supportingTransactionIDs = supportingTransactionIDs
        self.lastObservedDate = lastObservedDate
        self.nextExpectedDateWindow = nextExpectedDateWindow
    }
}
