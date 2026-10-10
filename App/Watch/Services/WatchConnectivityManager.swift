import Foundation
import WatchConnectivity
import HealthFamCore

/// Empfängt den Tagesstand vom iPhone und meldet beendete Trainings zurück.
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published private(set) var snapshot: WatchSnapshot?

    private let storageKey = "watchSnapshot"

    override private init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            snapshot = try? WatchSnapshot.decode(data)
        }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func notifyWorkoutFinished() {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo(["workoutFinished": Date().timeIntervalSince1970])
    }

    fileprivate func receive(_ data: Data) {
        guard let decoded = try? WatchSnapshot.decode(data) else { return }
        snapshot = decoded
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let data = session.receivedApplicationContext["snapshot"] as? Data
        Task { @MainActor in
            if let data { self.receive(data) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data else { return }
        Task { @MainActor in self.receive(data) }
    }
}
