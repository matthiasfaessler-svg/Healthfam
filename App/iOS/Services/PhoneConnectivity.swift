import Foundation
import WatchConnectivity
import HealthFamCore

/// Verbindung zur Apple Watch: schickt den aktuellen Tagesstand an die Uhr
/// und erfährt, wenn auf der Uhr ein Training beendet wurde.
@MainActor
final class PhoneConnectivity: NSObject, ObservableObject {
    @Published private(set) var isPaired = false
    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var isReachable = false

    /// Wird aufgerufen, wenn auf der Uhr ein Training beendet wurde.
    var onWorkoutFinished: (() -> Void)?

    private var pending: WatchSnapshot?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ snapshot: WatchSnapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            pending = snapshot
            return
        }
        guard session.isPaired, session.isWatchAppInstalled, let data = try? snapshot.encoded() else { return }
        try? session.updateApplicationContext(["snapshot": data])
    }

    private func updateState(_ session: WCSession) {
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
        if session.activationState == .activated, let pending {
            self.pending = nil
            send(pending)
        }
    }
}

extension PhoneConnectivity: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.updateState(session) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.updateState(session) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.updateState(session) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo["workoutFinished"] != nil else { return }
        Task { @MainActor in self.onWorkoutFinished?() }
    }
}
