import Foundation

/// Runtime configuration. The backend base URL is resolved (in priority order)
/// from: the `API_BASE_URL` environment variable, the `apiBaseURL` UserDefault,
/// the `APIBaseURL` Info.plist key, and finally a localhost default. No secrets
/// are compiled into the app.
enum AppConfig {
    static var baseURL: URL {
        if let env = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: env), !env.isEmpty {
            return url
        }
        if let override = UserDefaults.standard.string(forKey: "apiBaseURL"),
           let url = URL(string: override), !override.isEmpty {
            return url
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
           let url = URL(string: plist), !plist.isEmpty {
            return url
        }
        return URL(string: "http://localhost:8080")!
    }

    /// Persist a base-URL override (used by the in-app settings field).
    static func setBaseURLOverride(_ value: String?) {
        let ud = UserDefaults.standard
        if let value, !value.trimmingCharacters(in: .whitespaces).isEmpty {
            ud.set(value, forKey: "apiBaseURL")
        } else {
            ud.removeObject(forKey: "apiBaseURL")
        }
    }
}
