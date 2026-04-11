import Foundation
import UIKit

struct AppConfiguration {
    let appName: String = "Motchill"
    let apiBaseURL: URL = URL(string: "https://motchilltv.date")!
    let minimumIOSVersion: String = "18.0"
    let requestTimeout: TimeInterval = 20
    @MainActor
    var screenSize: CGSize {
        UIScreen.main.bounds.size
    }
    var requestHeaders: [String: String] {
        [
            "User-Agent": "Mozilla/5.0 (MotchillSwiftUI)",
            "Accept": "application/json,text/plain,*/*",
        ]
    }
}
