import Foundation
import HealthKit
import HealthFamCore

/// Zentrale Schnittstelle zu Apple Health – wird von iPhone und Apple Watch genutzt.
final class HealthKitService {
    static let shared = HealthKitService()

    let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Berechtigungen

    private let quantityReadIdentifiers: [HKQuantityTypeIdentifier] = [
        .heartRate,
        .restingHeartRate,
        .heartRateVariabilitySDNN,
        .respiratoryRate,
        .oxygenSaturation,
        .appleSleepingWristTemperature,
        .vo2Max,
        .stepCount,
        .activeEnergyBurned,
        .basalEnergyBurned,
        .distanceWalkingRunning,
        .bodyMass,
        .dietaryEnergyConsumed,
        .dietaryProtein,
        .dietaryCarbohydrates,
        .dietaryFatTotal,
        .dietaryWater
    ]

    private let quantityShareIdentifiers: [HKQuantityTypeIdentifier] = [
        .dietaryEnergyConsumed,
        .dietaryProtein,
        .dietaryCarbohydrates,
        .dietaryFatTotal,
        .dietaryWater,
        .activeEnergyBurned,
        .heartRate,
        .distanceWalkingRunning
    ]

    var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = Set(quantityReadIdentifiers.map { HKQuantityType($0) })
        types.insert(HKCategoryType(.sleepAnalysis))
        types.insert(HKCategoryType(.mindfulSession))
        types.insert(HKObjectType.workoutType())
        types.insert(HKObjectType.activitySummaryType())
        types.insert(HKCharacteristicType(.dateOfBirth))
        types.insert(HKCharacteristicType(.biologicalSex))
        return types
    }

    var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = Set(quantityShareIdentifiers.map { HKQuantityType($0) })
        types.insert(HKObjectType.workoutType())
        types.insert(HKCategoryType(.mindfulSession))
        return types
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    /// Liest Alter und Geschlecht aus Apple Health, sofern freigegeben.
    func profileCharacteristics() -> (age: Int?, sex: BiologicalSex?) {
        var age: Int?
        if let birth = try? store.dateOfBirthComponents(),
           let date = Calendar.current.date(from: birth) {
            age = Calendar.current.dateComponents([.year], from: date, to: Date()).year
        }
        var sex: BiologicalSex?
        if let value = try? store.biologicalSex().biologicalSex {
            switch value {
            case .female: sex = .female
            case .male: sex = .male
            case .other: sex = .other
            default: sex = nil
            }
        }
        return (age, sex)
    }

    // MARK: - Tagesdaten laden

    /// Lädt die Rohdaten der letzten `days` Tage (inklusive heute).
    func fetchHistory(days: Int, calendar: Calendar = .current) async throws -> [DailyMetrics] {
        guard isAvailable else { throw HealthKitError.notAvailable }
        let now = Date()
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today),
              let sleepStart = calendar.date(byAdding: .hour, value: -12, to: start),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        async let steps = dailyStatistics(.stepCount, unit: .count(), options: .cumulativeSum, start: start, end: end)
        async let active = dailyStatistics(.activeEnergyBurned, unit: .kilocalorie(), options: .cumulativeSum, start: start, end: end)
        async let basal = dailyStatistics(.basalEnergyBurned, unit: .kilocalorie(), options: .cumulativeSum, start: start, end: end)
        async let resting = dailyStatistics(.restingHeartRate, unit: .bpm, options: .discreteAverage, start: start, end: end)
        async let vo2 = dailyStatistics(.vo2Max, unit: .vo2Max, options: .discreteAverage, start: start, end: end)
        async let kcal = dailyStatistics(.dietaryEnergyConsumed, unit: .kilocalorie(), options: .cumulativeSum, start: start, end: end)
        async let protein = dailyStatistics(.dietaryProtein, unit: .gram(), options: .cumulativeSum, start: start, end: end)
        async let carbs = dailyStatistics(.dietaryCarbohydrates, unit: .gram(), options: .cumulativeSum, start: start, end: end)
        async let fat = dailyStatistics(.dietaryFatTotal, unit: .gram(), options: .cumulativeSum, start: start, end: end)
        async let water = dailyStatistics(.dietaryWater, unit: .literUnit(with: .milli), options: .cumulativeSum, start: start, end: end)
        async let heartRates = timedValues(.heartRate, unit: .bpm, start: start, end: end)
        async let hrvValues = timedValues(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: sleepStart, end: end)
        async let respiratory = timedValues(.respiratoryRate, unit: .perMinute, start: sleepStart, end: end)
        async let spo2 = timedValues(.oxygenSaturation, unit: .percent(), start: sleepStart, end: end)
        async let temperature = timedValues(.appleSleepingWristTemperature, unit: .degreeCelsius(), start: sleepStart, end: end)
        async let sleepSegments = sleepSegments(start: sleepStart, end: end)
        async let workouts = workouts(start: start, end: end)

        // Einzelne Datentypen können fehlen (z. B. ohne Apple Watch) – dann leer.
        let stepsByDay = (try? await steps) ?? [:]
        let activeByDay = (try? await active) ?? [:]
        let basalByDay = (try? await basal) ?? [:]
        let restingByDay = (try? await resting) ?? [:]
        let vo2ByDay = (try? await vo2) ?? [:]
        let kcalByDay = (try? await kcal) ?? [:]
        let proteinByDay = (try? await protein) ?? [:]
        let carbsByDay = (try? await carbs) ?? [:]
        let fatByDay = (try? await fat) ?? [:]
        let waterByDay = (try? await water) ?? [:]
        let hr = (try? await heartRates) ?? []
        let hrv = (try? await hrvValues) ?? []
        let rr = (try? await respiratory) ?? []
        let oxygen = (try? await spo2) ?? []
        let temp = (try? await temperature) ?? []
        let sleepByDay = SleepSessionBuilder.mainSleepByDay(from: (try? await sleepSegments) ?? [], calendar: calendar)
        let allWorkouts = (try? await workouts) ?? []

        let hrByDay = Dictionary(grouping: hr) { calendar.startOfDay(for: $0.date) }
        let workoutsByDay = Dictionary(grouping: allWorkouts) { calendar.startOfDay(for: $0.start) }

        var result: [DailyMetrics] = []
        var cursor = start
        while cursor < end {
            let day = cursor
            let sleep = sleepByDay[day]
            // Nächtliche Werte: während des Schlafs, sonst Nacht vor dem Tag.
            let nightStart = sleep?.start ?? day.addingTimeInterval(-4 * 3600)
            let nightEnd = sleep?.end ?? day.addingTimeInterval(8 * 3600)
            func night(_ values: [TimedValue]) -> [Double] {
                values.filter { $0.date >= nightStart && $0.date <= nightEnd }.map(\.value)
            }
            let hrvNight = night(hrv)
            let hrvDay = hrv.filter { calendar.isDate($0.date, inSameDayAs: day) }.map(\.value)

            result.append(DailyMetrics(
                day: day,
                hrv: Stats.mean(hrvNight.isEmpty ? hrvDay : hrvNight),
                restingHeartRate: restingByDay[day],
                respiratoryRate: Stats.mean(night(rr)),
                oxygenSaturation: Stats.mean(night(oxygen)),
                wristTemperature: Stats.mean(night(temp)),
                vo2Max: vo2ByDay[day],
                steps: stepsByDay[day] ?? 0,
                activeEnergy: activeByDay[day] ?? 0,
                basalEnergy: basalByDay[day] ?? 0,
                sleep: sleep,
                heartRateSamples: (hrByDay[day] ?? []).map { HeartRateSample(date: $0.date, bpm: $0.value) },
                workouts: workoutsByDay[day] ?? [],
                nutrition: NutritionSummary(
                    calories: kcalByDay[day] ?? 0,
                    protein: proteinByDay[day] ?? 0,
                    carbohydrates: carbsByDay[day] ?? 0,
                    fat: fatByDay[day] ?? 0,
                    water: waterByDay[day] ?? 0
                )
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    // MARK: - Abfragen

    func dailyStatistics(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        start: Date,
        end: Date
    ) async throws -> [Date: Double] {
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: options,
            anchorDate: Calendar.current.startOfDay(for: start),
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var values: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            let quantity = options.contains(.cumulativeSum) ? statistics.sumQuantity() : statistics.averageQuantity()
            if let quantity {
                values[statistics.startDate] = quantity.doubleValue(for: unit)
            }
        }
        return values
    }

    func timedValues(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> [TimedValue] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)
        return samples.map { TimedValue(date: $0.startDate, value: $0.quantity.doubleValue(for: unit)) }
    }

    func sleepSegments(start: Date, end: Date) async throws -> [SleepSegment] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)
        return samples.compactMap { sample in
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return nil }
            let stage: SleepStage
            switch value {
            case .inBed: stage = .inBed
            case .awake: stage = .awake
            case .asleepCore: stage = .core
            case .asleepDeep: stage = .deep
            case .asleepREM: stage = .rem
            case .asleepUnspecified: stage = .unspecified
            @unknown default: stage = .unspecified
            }
            return SleepSegment(
                start: sample.startDate,
                end: sample.endDate,
                stage: stage,
                source: sample.sourceRevision.source.bundleIdentifier
            )
        }
    }

    func workouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let workouts = try await descriptor.result(for: store)
        return workouts.map { workout in
            let heartRate = workout.statistics(for: HKQuantityType(.heartRate))
            let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))
                ?? workout.statistics(for: HKQuantityType(.distanceCycling))
                ?? workout.statistics(for: HKQuantityType(.distanceSwimming))
            return WorkoutSummary(
                id: workout.uuid,
                activityName: workout.workoutActivityType.displayName,
                symbolName: workout.workoutActivityType.symbolName,
                start: workout.startDate,
                end: workout.endDate,
                activeEnergy: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                distanceMeters: distance?.sumQuantity()?.doubleValue(for: .meter()),
                averageHeartRate: heartRate?.averageQuantity()?.doubleValue(for: .bpm),
                maxHeartRate: heartRate?.maximumQuantity()?.doubleValue(for: .bpm)
            )
        }
    }

    // MARK: - Schreiben

    func saveNutrition(calories: Double, protein: Double, carbohydrates: Double, fat: Double, date: Date = Date()) async throws {
        var samples: [HKQuantitySample] = []
        func add(_ identifier: HKQuantityTypeIdentifier, _ value: Double, _ unit: HKUnit) {
            guard value > 0 else { return }
            samples.append(HKQuantitySample(
                type: HKQuantityType(identifier),
                quantity: HKQuantity(unit: unit, doubleValue: value),
                start: date,
                end: date
            ))
        }
        add(.dietaryEnergyConsumed, calories, .kilocalorie())
        add(.dietaryProtein, protein, .gram())
        add(.dietaryCarbohydrates, carbohydrates, .gram())
        add(.dietaryFatTotal, fat, .gram())
        guard !samples.isEmpty else { return }
        try await store.save(samples)
    }

    func saveWater(milliliters: Double, date: Date = Date()) async throws {
        let sample = HKQuantitySample(
            type: HKQuantityType(.dietaryWater),
            quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: milliliters),
            start: date,
            end: date
        )
        try await store.save(sample)
    }

    func saveMindfulSession(start: Date, end: Date) async throws {
        let sample = HKCategorySample(
            type: HKCategoryType(.mindfulSession),
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )
        try await store.save(sample)
    }

    // MARK: - Hintergrund-Aktualisierung

    private var observers: [HKObserverQuery] = []

    /// Meldet neue Daten (z. B. Sync von der Apple Watch) – auch im Hintergrund.
    func startObserving(onChange: @escaping @Sendable () -> Void) {
        guard observers.isEmpty, isAvailable else { return }
        let types: [HKSampleType] = [
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.workoutType()
        ]
        for type in types {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                if error == nil { onChange() }
                completion()
            }
            store.execute(query)
            observers.append(query)
            #if os(iOS)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
            #endif
        }
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Apple Health ist auf diesem Gerät nicht verfügbar."
        }
    }
}

extension HKUnit {
    static let bpm = HKUnit.count().unitDivided(by: .minute())
    static let perMinute = HKUnit.count().unitDivided(by: .minute())
    static let vo2Max = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
}
