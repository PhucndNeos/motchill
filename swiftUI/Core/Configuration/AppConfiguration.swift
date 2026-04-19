import Foundation
import UIKit

struct AppConfiguration {
    let appName: String = "PhucTv"
    private let remoteConfigStore: PhucTvRemoteConfigStoring

    init(remoteConfigStore: PhucTvRemoteConfigStoring = PhucTvRemoteConfigStore.shared) {
        self.remoteConfigStore = remoteConfigStore
    }

    var apiBaseURL: URL? {
        remoteConfigStore.current?.apiBaseURL
    }

    var passphrase: String? {
        remoteConfigStore.current?.key
    }

    var supabaseURL: URL? {
        stringValue(forInfoKey: "SUPABASE_URL").flatMap(URL.init(string:))
    }

    var supabasePublishableKey: String? {
        stringValue(forInfoKey: "SUPABASE_PUBLISHABLE_KEY")
            ?? stringValue(forInfoKey: "SUPABASE_ANON_KEY")
    }

    var supabaseAuthRedirectURL: URL? {
        URL(string: "phuctv://auth-callback")
    }

    let minimumIOSVersion: String = "18.0"
    let requestTimeout: TimeInterval = 20
    @MainActor
    var screenSize: CGSize {
        UIScreen.main.bounds.size
    }
    @MainActor
    var safeArea: UIEdgeInsets? {
        UIApplication.shared.delegate?.window??.safeAreaInsets
    }
    var requestHeaders: [String: String] {
        [
            "User-Agent": "Mozilla/5.0 (PhucTvSwiftUI)",
            "Accept": "application/json,text/plain,*/*",
        ]
    }

    private func stringValue(forInfoKey key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
