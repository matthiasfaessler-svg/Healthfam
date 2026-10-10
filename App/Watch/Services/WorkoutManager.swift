import Foundation
import HealthKit
import HealthFamCore

/// Steuert ein Live-Training auf der Apple Watch inkl. Echtzeit-Strain.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    enum State { case idle, running, paused, finished }

    @Published private(set) var state: State = .idle
    @Published private(set) var activity: HKWorkoutActivityType = .running
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var averageHeartRate: Double = 0
    @Published private(set) var activeEnergy: Double = 0
    @Published private(set) var distance: Double = 0
    @Published private(set) var workoutStrain: Int = 0
    @Published private(set) var dayStrain: Int = 0
    @Published private(set) var zone: Int = 0
    @Published private(set) var finishedWorkout: HKWorkout?
    @Published var errorMessage: String?

    private let store = HealthKitService.shared.store
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var samples: [HeartRateSample] = []
    private var startDate: Date?

    /// Wird vom Tagesstand gesetzt, damit der Live-Strain den bisherigen Tag einbezieht.
    var profile = UserProfile()
    var restingHeartRate: Double = 60
    var strainBeforeWorkout: Int = 0

    var elapsedTime: TimeInterval { builder?.elapsedTime ?? 0 }
    var isActive: Bool { state == .running || state == .paused }

    // MARK: - Steuerung

    func start(_ type: HKWorkoutActivityType) async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = type
            configuration.locationType = type.isOutdoorCapable ? .outdoor : .indoor
            if type == .swimming {
                configuration.swimmingLocationType = .pool
                configuration.lapLength = HKQuantity(unit: .meter(), doubleValue: 25)
            }

            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self

            self.session = session
            self.builder = builder
            reset()
            activity = type

            let start = Date()
            startDate = start
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            state = .running
        } catch {
            errorMessage = error.localizedDescription
            state = .idle
        }
    }

    func togglePause() {
        guard let session else { return }
        if state == .running {
            session.pause()
        } else if state == .paused {
            session.resume()
        }
    }

    func end() {
        session?.end()
    }

    func dismissSummary() {
        state = .idle
        finishedWorkout = nil
        session = nil
        builder = nil
    }

    private func reset() {
        samples = []
        heartRate = 0
        averageHeartRate = 0
        activeEnergy = 0
        distance = 0
        workoutStrain = 0
        dayStrain = strainBeforeWorkout
        zone = 0
        finishedWorkout = nil
    }

    // MARK: - Live-Daten

    private func handle(statistics: HKStatistics) {
        switch statistics.quantityType {
        case HKQuantityType(.heartRate):
            let unit = HKUnit.count().unitDivided(by: .minute())
            heartRate = statistics.mostRecentQuantity()?.doubleValue(for: unit) ?? heartRate
            averageHeartRate = statistics.averageQuantity()?.doubleValue(for: unit) ?? averageHeartRate
            if heartRate > 0 {
                samples.append(HeartRateSample(date: Date(), bpm: heartRate))
                updateStrain()
            }
        case HKQuantityType(.activeEnergyBurned):
            activeEnergy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? activeEnergy
        case HKQuantityType(.distanceWalkingRunning), HKQuantityType(.distanceCycling), HKQuantityType(.distanceSwimming):
            distance = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? distance
        default:
            break
        }
    }

    private func updateStrain() {
        let result = StrainCalculator.trimp(
            samples: samples,
            restingHeartRate: restingHeartRate,
            maxHeartRate: profile.maxHeartRate,
            sex: profile.sex
        )
        workoutStrain = StrainCalculator.score(forTRIMP: result.trimp)
        // Bisherigen Tages-Strain in TRIMP zurückrechnen und addieren.
        let priorFraction = min(Double(strainBeforeWorkout) / 100, 0.999)
        let priorTRIMP = -StrainCalculator.scale * log(1 - priorFraction)
        dayStrain = StrainCalculator.score(forTRIMP: priorTRIMP + result.trimp)

        let reserve = max(profile.maxHeartRate - restingHeartRate, 1)
        let hrr = (heartRate - restingHeartRate) / reserve
        zone = hrr < 0.5 ? 0 : min(5, Int((hrr - 0.5) / 0.1) + 1)
    }

    private func finish(endDate: Date) async {
        guard let builder else { return }
        do {
            try await builder.endCollection(at: endDate)
            finishedWorkout = try await builder.finishWorkout()
        } catch {
            errorMessage = error.localizedDescription
        }
        state = .finished
        WatchConnectivityManager.shared.notifyWorkoutFinished()
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running: self.state = .running
            case .paused: self.state = .paused
            case .ended: await self.finish(endDate: date)
            default: break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.errorMessage = error.localizedDescription }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let statistics = collectedTypes.compactMap { type -> HKStatistics? in
            guard let quantityType = type as? HKQuantityType else { return nil }
            return workoutBuilder.statistics(for: quantityType)
        }
        Task { @MainActor in
            statistics.forEach(self.handle(statistics:))
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
