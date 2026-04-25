import Domain
import Foundation
import Testing

@Test
func analysisIntervalResolverResolvesMonthToDateWithPreviousPeriodComparison() {
    let resolution = AnalysisIntervalResolver.resolve(
        range: .monthToDate,
        comparison: .previousPeriod,
        referenceDate: analysisUTCDate(year: 2026, month: 4, day: 24)
    )

    #expect(resolution.currentLabel == "Month to Date")
    #expect(resolution.currentInterval == DateInterval(
        start: analysisUTCDate(year: 2026, month: 4, day: 1),
        end: analysisUTCDate(year: 2026, month: 4, day: 25)
    ))
    #expect(resolution.paceRatio == Decimal(string: "0.8"))
    #expect(resolution.comparison == .interval(
        DateInterval(
            start: analysisUTCDate(year: 2026, month: 3, day: 1),
            end: analysisUTCDate(year: 2026, month: 3, day: 25)
        ),
        label: "Previous Period"
    ))
}

@Test
func analysisIntervalResolverResolvesLastFullMonthAsClosedPeriod() {
    let resolution = AnalysisIntervalResolver.resolve(
        range: .lastFullMonth,
        comparison: .previousPeriod,
        referenceDate: analysisUTCDate(year: 2026, month: 4, day: 24)
    )

    #expect(resolution.currentLabel == "Last Full Month")
    #expect(resolution.currentInterval == DateInterval(
        start: analysisUTCDate(year: 2026, month: 3, day: 1),
        end: analysisUTCDate(year: 2026, month: 4, day: 1)
    ))
    #expect(resolution.paceRatio == Decimal(1))
    #expect(resolution.comparison == .interval(
        DateInterval(
            start: analysisUTCDate(year: 2026, month: 2, day: 1),
            end: analysisUTCDate(year: 2026, month: 3, day: 1)
        ),
        label: "Previous Period"
    ))
}

@Test
func analysisIntervalResolverResolvesYearToDateAgainstSamePeriodLastYear() {
    let resolution = AnalysisIntervalResolver.resolve(
        range: .yearToDate,
        comparison: .samePeriodLastYear,
        referenceDate: analysisUTCDate(year: 2026, month: 4, day: 24)
    )

    #expect(resolution.currentLabel == "Year to Date")
    #expect(resolution.currentInterval == DateInterval(
        start: analysisUTCDate(year: 2026, month: 1, day: 1),
        end: analysisUTCDate(year: 2026, month: 4, day: 25)
    ))
    #expect(resolution.comparison == .interval(
        DateInterval(
            start: analysisUTCDate(year: 2025, month: 1, day: 1),
            end: analysisUTCDate(year: 2025, month: 4, day: 25)
        ),
        label: "Same Period Last Year"
    ))
}

@Test
func analysisIntervalResolverResolvesCustomRangeWithoutComparison() {
    let customInterval = DateInterval(
        start: analysisUTCDate(year: 2026, month: 2, day: 10),
        end: analysisUTCDate(year: 2026, month: 2, day: 18)
    )
    let resolution = AnalysisIntervalResolver.resolve(
        range: .custom(customInterval),
        comparison: .none,
        referenceDate: analysisUTCDate(year: 2026, month: 4, day: 24)
    )

    #expect(resolution.currentLabel == "Custom Range")
    #expect(resolution.currentInterval == customInterval)
    #expect(resolution.comparison == .none)
    #expect(resolution.paceRatio == Decimal(1))
}

@Test
func analysisIntervalResolverBuildsRollingThreeMonthAverageFromClosedMonths() {
    let resolution = AnalysisIntervalResolver.resolve(
        range: .monthToDate,
        comparison: .rollingAverage(months: 3),
        referenceDate: analysisUTCDate(year: 2026, month: 4, day: 24)
    )

    #expect(resolution.comparison == .rollingAverage(
        intervals: [
            DateInterval(
                start: analysisUTCDate(year: 2026, month: 3, day: 1),
                end: analysisUTCDate(year: 2026, month: 3, day: 25)
            ),
            DateInterval(
                start: analysisUTCDate(year: 2026, month: 2, day: 1),
                end: analysisUTCDate(year: 2026, month: 2, day: 25)
            ),
            DateInterval(
                start: analysisUTCDate(year: 2026, month: 1, day: 1),
                end: analysisUTCDate(year: 2026, month: 1, day: 25)
            ),
        ],
        label: "Rolling 3-Month Average"
    ))
}

@Test
func analysisIntervalResolverClampsShorterPreviousPeriodAndLeapYearComparisons() {
    let shortMonth = AnalysisIntervalResolver.resolve(
        range: .monthToDate,
        comparison: .previousPeriod,
        referenceDate: analysisUTCDate(year: 2025, month: 3, day: 31)
    )
    let leapYear = AnalysisIntervalResolver.resolve(
        range: .monthToDate,
        comparison: .samePeriodLastYear,
        referenceDate: analysisUTCDate(year: 2024, month: 2, day: 29)
    )

    #expect(shortMonth.currentInterval == DateInterval(
        start: analysisUTCDate(year: 2025, month: 3, day: 1),
        end: analysisUTCDate(year: 2025, month: 4, day: 1)
    ))
    #expect(shortMonth.comparison == .interval(
        DateInterval(
            start: analysisUTCDate(year: 2025, month: 2, day: 1),
            end: analysisUTCDate(year: 2025, month: 3, day: 1)
        ),
        label: "Previous Period"
    ))
    #expect(leapYear.currentInterval == DateInterval(
        start: analysisUTCDate(year: 2024, month: 2, day: 1),
        end: analysisUTCDate(year: 2024, month: 3, day: 1)
    ))
    #expect(leapYear.comparison == .interval(
        DateInterval(
            start: analysisUTCDate(year: 2023, month: 2, day: 1),
            end: analysisUTCDate(year: 2023, month: 3, day: 1)
        ),
        label: "Same Period Last Year"
    ))
}

@Test
func analysisIntervalResolverUsesUTCCalendarAndKeepsIntervalsValid() {
    let resolution = AnalysisIntervalResolver.resolve(
        range: .monthToDate,
        comparison: .none,
        referenceDate: analysisUTCDate(year: 2026, month: 4, day: 24)
    )

    #expect(resolution.timeZone == TimeZone(secondsFromGMT: 0))
    #expect(resolution.calendar.timeZone == TimeZone(secondsFromGMT: 0))
    #expect(resolution.currentInterval.start < resolution.currentInterval.end)
    #expect(resolution.paceRatio > 0)
    #expect(resolution.paceRatio <= Decimal(1))
}

private func analysisUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    return components.date!
}
