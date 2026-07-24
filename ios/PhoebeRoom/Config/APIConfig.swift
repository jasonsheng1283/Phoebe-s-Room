import Foundation

enum APIConfig {
    static let defaultBaseURLString = "http://127.0.0.1:8000/api/v1"
    private static let overrideKey = "apiBaseURL"

    static var baseURLString: String {
        get {
            #if DEBUG
            if let override = UserDefaults.standard.string(forKey: overrideKey), !override.isEmpty {
                return override
            }
            #endif
            return defaultBaseURLString
        }
        set {
            #if DEBUG
            UserDefaults.standard.set(newValue, forKey: overrideKey)
            #endif
        }
    }

    static var baseURL: URL {
        URL(string: baseURLString) ?? URL(string: defaultBaseURLString)!
    }

    static func resetToDefault() {
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: overrideKey)
        #endif
    }
}
