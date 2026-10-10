import XCTest
@testable import HealthFamCore

final class HealthFamCoreTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return calendar
    }

    private func day(_ offset: Int) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        return calendar.date(byAdding: .day, value: offset, to: base)!
    }

    private func history(hrv: Double = 60, rhr: Double = 52, days: Int = 20) -> [DailyMetrics] {
        (0..<days).map { i in
            DailyMetrics(day: day(i), hrv: hrv + Double(i % 3) - 1, restingHeartRate: rhr + Double(i % 2))
        }
    }

    // MARK: Statistik

    func testStatistics() {
        XCTAssertEqual(Stats.mean([1, 2, 3]), 2)
        XCTAssertEqual(Stats.median([5, 1, 3, 2]), 2.5)
        XCTAssertEqual(Stats.standardDeviation([2, 4, 4, 4, 5, 5, 7, 9])!, 2.138, accuracy: 0.001)
        XCTAssertNil(Stats.mean([]))
        XCTAssertNil(MetricBaseline(values: [1, 2]))
    }

    // MARK: Recovery

    func testRecoveryRisesWithHRVAndFallsWithRestingHeartRate() {
        let past = history()
        let baseline = PersonalBaseline.compute(from: past, before: day(20), calendar: calendar)

        let good = RecoveryCalculator.calculate(metrics: DailyMetrics(day: day(20), hrv: 75, restingHeartRate: 49), baseline: baseline, sleepScore: 85)!
        let normal = RecoveryCalculator.calculate(metrics: DailyMetrics(day: day(20), hrv: 60, restingHeartRate: 52.5), baseline: baseline, sleepScore: 70)!
        let bad = RecoveryCalculator.calculate(metrics: DailyMetrics(day: day(20), hrv: 42, restingHeartRate: 58), baseline: baseline, sleepScore: 45)!

        XCTAssertGreaterThan(good.score, normal.score)
        XCTAssertGreaterThan(normal.score, bad.score)
        XCTAssertEqual(good.level, .high)
        XCTAssertEqual(bad.level, .low)
        XCTAssertFalse(good.isCalibrating)
        XCTAssertTrue((1...99).contains(good.score))
    }

    func testRecoveryNeedsHeartData() {
        XCTAssertNil(RecoveryCalculator.calculate(metrics: DailyMetrics(day: day(0)), baseline: PersonalBaseline(), sleepScore: 80))
        let calibrating = RecoveryCalculator.calculate(metrics: DailyMetrics(day: day(0), hrv: 50), baseline: PersonalBaseline(), sleepScore: nil)
        XCTAssertEqual(calibrating?.isCalibrating, true)
    }

    // MARK: Strain

    func testStrainIsZeroAtRestAndGrowsWithIntensity() {
        let start = day(0)
        let rest = (0..<120).map { HeartRateSample(date: start.addingTimeInterval(Double($0) * 60), bpm: 60) }
        let easy = (0..<60).map { HeartRateSample(date: start.addingTimeInterval(Double($0) * 60), bpm: 130) }
        let hard = (0..<60).map { HeartRateSample(date: start.addingTimeInterval(Double($0) * 60), bpm: 170) }

        let restResult = StrainCalculator.calculate(samples: rest, restingHeartRate: 55, maxHeartRate: 190, sex: .male)
        let easyResult = StrainCalculator.calculate(samples: easy, restingHeartRate: 55, maxHeartRate: 190, sex: .male)
        let hardResult = StrainCalculator.calculate(samples: hard, restingHeartRate: 55, maxHeartRate: 190, sex: .male)

        XCTAssertEqual(restResult.score, 0)
        XCTAssertGreaterThan(easyResult.score, 0)
        XCTAssertGreaterThan(hardResult.score, easyResult.score)
        XCTAssertLessThanOrEqual(hardResult.score, 100)
        XCTAssertGreaterThan(hardResult.zones[3].duration, 0)
    }

    func testStrainIgnoresLongGaps() {
        let start = day(0)
        let samples = [
            HeartRateSample(date: start, bpm: 150),
            HeartRateSample(date: start.addingTimeInterval(6 * 3600), bpm: 150)
        ]
        let result = StrainCalculator.trimp(samples: samples, restingHeartRate: 55, maxHeartRate: 190, sex: .male)
        // Zwei Messungen à max. 1 Minute, nicht 6 Stunden.
        XCTAssertLessThan(result.trimp, 10)
    }

    // MARK: Schlaf

    func testSleepScoreRewardsLongerRestorativeSleep() {
        let bed = calendar.date(byAdding: .hour, value: -1, to: day(1))!
        func session(hours: Double, deepShare: Double) -> SleepSession {
            let total = hours * 3600
            return SleepSession(segments: [
                SleepSegment(start: bed, end: bed.addingTimeInterval(total * deepShare), stage: .deep),
                SleepSegment(start: bed.addingTimeInterval(total * deepShare), end: bed.addingTimeInterval(total), stage: .core)
            ])
        }
        let profile = UserProfile(sleepGoalHours: 8)
        let long = SleepCalculator.calculate(session: session(hours: 8, deepShare: 0.4), profile: profile, baseline: PersonalBaseline(), previousStrain: nil, calendar: calendar)!
        let short = SleepCalculator.calculate(session: session(hours: 5, deepShare: 0.1), profile: profile, baseline: PersonalBaseline(), previousStrain: nil, calendar: calendar)!

        XCTAssertGreaterThan(long.score, 90)
        XCTAssertLessThan(short.score, long.score)
        XCTAssertGreaterThan(
            SleepCalculator.sleepNeed(profile: profile, previousStrain: 80),
            SleepCalculator.sleepNeed(profile: profile, previousStrain: 10)
        )
    }

    func testSleepBuilderPrefersStagedSourceAndAssignsWakeDay() {
        let bed = calendar.date(byAdding: .hour, value: -1, to: day(5))!
        let segments = [
            SleepSegment(start: bed, end: bed.addingTimeInterval(4 * 3600), stage: .core, source: "watch"),
            SleepSegment(start: bed.addingTimeInterval(4 * 3600), end: bed.addingTimeInterval(7 * 3600), stage: .rem, source: "watch"),
            SleepSegment(start: bed, end: bed.addingTimeInterval(8 * 3600), stage: .unspecified, source: "phone")
        ]
        let byDay = SleepSessionBuilder.mainSleepByDay(from: segments, calendar: calendar)
        XCTAssertEqual(byDay.count, 1)
        let session = byDay[day(5)]
        XCTAssertNotNil(session)
        XCTAssertEqual(session!.asleepDuration, 7 * 3600, accuracy: 1)
        XCTAssertTrue(session!.hasStages)
    }

    func testBedtimeMinutesWrapAroundMidnight() {
        let late = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day(0))!
        let early = calendar.date(bySettingHour: 0, minute: 30, second: 0, of: day(1))!
        XCTAssertEqual(PersonalBaseline.bedtimeMinutes(late, calendar: calendar), -60)
        XCTAssertEqual(PersonalBaseline.bedtimeMinutes(early, calendar: calendar), 30)
    }

    // MARK: Journal

    func testJournalImpactComparesNextDayRecovery() {
        var entries: [JournalEntry] = []
        var recovery: [Date: Int] = [:]
        for i in 0..<12 {
            let drank = i.isMultiple(of: 2)
            entries.append(JournalEntry(day: day(i), tagIDs: drank ? ["alcohol"] : ["reading"]))
            recovery[day(i + 1)] = drank ? 40 : 75
        }
        let impacts = JournalAnalyzer.impacts(entries: entries, recoveryByDay: recovery, calendar: calendar)
        let alcohol = impacts.first { $0.tagID == "alcohol" }
        XCTAssertNotNil(alcohol)
        XCTAssertEqual(alcohol!.delta, -35, accuracy: 0.01)
        XCTAssertEqual(alcohol!.occurrences, 6)
    }

    // MARK: Gesamtanalyse

    func testAnalyzerProducesScoresForDemoData() {
        let end = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: day(60))!
        let data = DemoDataGenerator.generate(days: 45, endingAt: end, calendar: calendar)
        let analysis = HealthAnalyzer.analyze(history: data, profile: UserProfile(age: 32, sex: .male), calendar: calendar)

        XCTAssertEqual(analysis.count, 45)
        let last = analysis.last!
        XCTAssertNotNil(last.recovery)
        XCTAssertNotNil(last.sleep)
        XCTAssertNotNil(last.stress)
        XCTAssertNotNil(last.energy)
        XCTAssertFalse(last.recovery!.isCalibrating)
        XCTAssertTrue(analysis.contains { $0.strain.score > 30 })
    }

    func testDemoDataIsDeterministic() {
        let end = day(30)
        let a = DemoDataGenerator.generate(days: 5, endingAt: end, seed: 7, calendar: calendar)
        let b = DemoDataGenerator.generate(days: 5, endingAt: end, seed: 7, calendar: calendar)
        XCTAssertEqual(a, b)
    }

    func testWatchSnapshotRoundTrip() throws {
        let data = DemoDataGenerator.generate(days: 10, endingAt: day(10), calendar: calendar)
        let analysis = HealthAnalyzer.analyze(history: data, profile: UserProfile(), calendar: calendar).last!
        let snapshot = WatchSnapshot(analysis: analysis, profile: UserProfile())
        XCTAssertEqual(try WatchSnapshot.decode(snapshot.encoded()), snapshot)
    }

    func testFormatters() {
        XCTAssertEqual(Formatters.duration(7 * 3600 + 32 * 60), "7 h 32 min")
        XCTAssertEqual(Formatters.duration(45 * 60), "45 min")
        XCTAssertEqual(Formatters.clock(3912), "1:05:12")
    }
}
