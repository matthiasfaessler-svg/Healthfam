import Foundation
import HealthFamCore

/// Persistente Einstellungen und Nutzerprofil.
@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    @Published var useDemoData: Bool {
        didSet { defaults.set(useDemoData, forKey: Keys.demo) }
    }

    @Published var sexEditedManually: Bool {
        didSet { defaults.set(sexEditedManually, forKey: Keys.sexEdited) }
    }

    @Published var profile: UserProfile {
        didSet {
            if let data = try? JSONEncoder().encode(profile) {
                defaults.set(data, forKey: Keys.profile)
            }
        }
    }

    init() {
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        useDemoData = defaults.bool(forKey: Keys.demo)
        sexEditedManually = defaults.bool(forKey: Keys.sexEdited)
        if let data = defaults.data(forKey: Keys.profile),
           let stored = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = stored
        } else {
            profile = UserProfile()
        }
    }

    private enum Keys {
        static let onboarding = "hasCompletedOnboarding"
        static let demo = "useDemoData"
        static let sexEdited = "sexEditedManually"
        static let profile = "userProfile"
    }
}
