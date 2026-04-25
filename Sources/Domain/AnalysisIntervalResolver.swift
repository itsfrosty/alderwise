import Foundation

public enum AnalysisResolvedComparison: Equatable, Sendable {
    case none
    case interval(DateInterval, label: String)
    case rollingAverage(intervals: [DateInterval], label: String)
    case unsupported(reason: String)
}

public struct AnalysisIntervalResolution: Equatable, Sendable {
    public var currentInterval: DateInterval
    public var currentLabel: String
    public var comparison: AnalysisResolvedComparison
    public var paceRatio: Decimal
    public var calendar: Calendar
    public var timeZone: TimeZone

    public init(
        currentInterval: DateInterval,
        currentLabel: String,
        comparison: AnalysisResolvedComparison,
        paceRatio: Decimal,
        calendar: Calendar,
        timeZone: TimeZone
    ) {
        self.currentInterval = currentInterval
        self.currentLabel = currentLabel
        self.comparison = comparison
        self.paceRatio = paceRatio
        self.calendar = calendar
        self.timeZone = timeZone
    }
}

public enum AnalysisIntervalResolver {
    public static func resolve(
        range: AnalysisRange,
        comparison: AnalysisComparisonMode,
        referenceDate: Date
    ) -> AnalysisIntervalResolution {
        let calendar = Calendar.alderwiseAnalysisUTC
        let timeZone = calendar.timeZone
        let currentInterval = currentInterval(for: range, referenceDate: referenceDate, calendar: calendar)
        let currentLabel = label(for: range)
        let paceRatio = paceRatio(for: range, referenceDate: referenceDate, currentInterval: currentInterval, calendar: calendar)

        return AnalysisIntervalResolution(
            currentInterval: currentInterval,
            currentLabel: currentLabel,
            comparison: resolveComparison(
                mode: comparison,
                range: range,
                currentInterval: currentInterval,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            paceRatio: paceRatio,
            calendar: calendar,
            timeZone: timeZone
        )
    }

    private static func currentInterval(
        for range: AnalysisRange,
        referenceDate: Date,
        calendar: Calendar
    ) -> DateInterval {
        switch range {
        case .monthToDate:
            let start = startOfMonth(containing: referenceDate, calendar: calendar)
            return DateInterval(start: start, end: nextDayStart(after: referenceDate, calendar: calendar))
        case .lastFullMonth:
            let currentMonthStart = startOfMonth(containing: referenceDate, calendar: calendar)
            let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
            return DateInterval(start: previousMonthStart, end: currentMonthStart)
        case .yearToDate:
            let start = startOfYear(containing: referenceDate, calendar: calendar)
            return DateInterval(start: start, end: nextDayStart(after: referenceDate, calendar: calendar))
        case .custom(let interval):
            return interval
        }
    }

    private static func resolveComparison(
        mode: AnalysisComparisonMode,
        range: AnalysisRange,
        currentInterval: DateInterval,
        referenceDate: Date,
        calendar: Calendar
    ) -> AnalysisResolvedComparison {
        switch mode {
        case .none:
            return .none
        case .previousPeriod:
            return .interval(
                previousPeriod(for: range, currentInterval: currentInterval, calendar: calendar),
                label: "Previous Period"
            )
        case .samePeriodLastYear:
            return .interval(
                samePeriodLastYear(for: currentInterval, calendar: calendar),
                label: "Same Period Last Year"
            )
        case .rollingAverage(let months):
            guard months > 0 else {
                return .unsupported(reason: "Rolling average requires at least one prior period.")
            }
            return .rollingAverage(
                intervals: rollingAverageSamples(
                    for: range,
                    currentInterval: currentInterval,
                    referenceDate: referenceDate,
                    months: months,
                    calendar: calendar
                ),
                label: "Rolling \(months)-Month Average"
            )
        }
    }

    private static func previousPeriod(
        for range: AnalysisRange,
        currentInterval: DateInterval,
        calendar: Calendar
    ) -> DateInterval {
        switch range {
        case .monthToDate:
            let currentMonthStart = currentInterval.start
            let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
            let dayCount = inclusiveDayCount(for: currentInterval, calendar: calendar)
            let unclampedEnd = calendar.date(byAdding: .day, value: dayCount, to: previousMonthStart) ?? currentMonthStart
            return DateInterval(start: previousMonthStart, end: min(unclampedEnd, currentMonthStart))
        case .lastFullMonth:
            let end = currentInterval.start
            let start = calendar.date(byAdding: .month, value: -1, to: end) ?? end
            return DateInterval(start: start, end: end)
        case .yearToDate, .custom:
            let dayCount = dayCount(for: currentInterval, calendar: calendar)
            let end = currentInterval.start
            let start = calendar.date(byAdding: .day, value: -dayCount, to: end) ?? end
            return DateInterval(start: start, end: end)
        }
    }

    private static func samePeriodLastYear(for currentInterval: DateInterval, calendar: Calendar) -> DateInterval {
        let start = calendar.date(byAdding: .year, value: -1, to: currentInterval.start) ?? currentInterval.start
        let end = calendar.date(byAdding: .year, value: -1, to: currentInterval.end) ?? currentInterval.end
        return DateInterval(start: start, end: end)
    }

    private static func rollingAverageSamples(
        for range: AnalysisRange,
        currentInterval: DateInterval,
        referenceDate: Date,
        months: Int,
        calendar: Calendar
    ) -> [DateInterval] {
        switch range {
        case .monthToDate:
            let includedDays = inclusiveDayCount(for: currentInterval, calendar: calendar)
            return (1 ... months).compactMap { offset in
                guard let monthStart = calendar.date(
                    byAdding: .month,
                    value: -offset,
                    to: startOfMonth(containing: referenceDate, calendar: calendar)
                ) else {
                    return nil
                }
                let unclampedEnd = calendar.date(byAdding: .day, value: includedDays, to: monthStart) ?? monthStart
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? unclampedEnd
                return DateInterval(start: monthStart, end: min(unclampedEnd, monthEnd))
            }
        case .lastFullMonth:
            return (1 ... months).compactMap { offset in
                guard let end = calendar.date(byAdding: .month, value: -offset + 1, to: currentInterval.start),
                      let start = calendar.date(byAdding: .month, value: -1, to: end) else {
                    return nil
                }
                return DateInterval(start: start, end: end)
            }
        case .yearToDate, .custom:
            let sample = previousPeriod(for: range, currentInterval: currentInterval, calendar: calendar)
            return Array(repeating: sample, count: months)
        }
    }

    private static func paceRatio(
        for range: AnalysisRange,
        referenceDate: Date,
        currentInterval: DateInterval,
        calendar: Calendar
    ) -> Decimal {
        switch range {
        case .monthToDate:
            let elapsedDays = inclusiveDayCount(for: currentInterval, calendar: calendar)
            let totalDays = calendar.range(of: .day, in: .month, for: referenceDate)?.count ?? elapsedDays
            return Decimal(elapsedDays) / Decimal(totalDays)
        case .lastFullMonth, .yearToDate, .custom:
            return Decimal(1)
        }
    }

    private static func label(for range: AnalysisRange) -> String {
        switch range {
        case .monthToDate:
            "Month to Date"
        case .lastFullMonth:
            "Last Full Month"
        case .yearToDate:
            "Year to Date"
        case .custom:
            "Custom Range"
        }
    }

    private static func startOfMonth(containing date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private static func startOfYear(containing date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year], from: date)) ?? date
    }

    private static func nextDayStart(after date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    }

    private static func dayCount(for interval: DateInterval, calendar: Calendar) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: interval.start),
            to: calendar.startOfDay(for: interval.end)
        ).day ?? 0
    }

    private static func inclusiveDayCount(for interval: DateInterval, calendar: Calendar) -> Int {
        max(dayCount(for: interval, calendar: calendar), 0)
    }
}

private extension Calendar {
    static var alderwiseAnalysisUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
