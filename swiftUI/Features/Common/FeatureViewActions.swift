import Foundation
import UIKit

@MainActor
func makeAsyncAction(_ operation: @escaping @MainActor () async -> Void) -> () -> Void {
    {
        Task {
            await operation()
        }
    }
}

@MainActor
func openExternalURL(_ rawValue: String?) {
    guard let url = normalizedExternalURL(from: rawValue) else { return }
    UIApplication.shared.open(url)
}

private func normalizedExternalURL(from rawValue: String?) -> URL? {
    guard let rawValue else { return nil }
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if let directURL = URL(string: trimmed), let scheme = directURL.scheme?.lowercased(), scheme == "http" || scheme == "https" {
        return directURL
    }

    if trimmed.hasPrefix("//"), let protocolRelativeURL = URL(string: "https:\(trimmed)") {
        return protocolRelativeURL
    }

    if let inferredURL = URL(string: "https://\(trimmed)") {
        return inferredURL
    }

    return nil
}
