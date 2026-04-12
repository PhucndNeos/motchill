import SwiftUI

struct FeatureOverlayDescriptor {
    let title: String
    let message: String
    let retryTitle: String
    let secondaryTitle: String?
    let errorCode: String?
    let icon: ErrorOverlay.Icon
    let isLoading: Bool

    static func loading(
        title: String,
        message: String,
        errorCode: String,
        retryTitle: String = "Tải lại"
    ) -> FeatureOverlayDescriptor {
        FeatureOverlayDescriptor(
            title: title,
            message: message,
            retryTitle: retryTitle,
            secondaryTitle: nil,
            errorCode: errorCode,
            icon: .loading,
            isLoading: true
        )
    }

    static func failure(
        title: String,
        message: String,
        errorCode: String,
        icon: ErrorOverlay.Icon,
        retryTitle: String = "Thử lại",
        secondaryTitle: String? = nil
    ) -> FeatureOverlayDescriptor {
        FeatureOverlayDescriptor(
            title: title,
            message: message,
            retryTitle: retryTitle,
            secondaryTitle: secondaryTitle,
            errorCode: errorCode,
            icon: icon,
            isLoading: false
        )
    }

    static func empty(
        title: String,
        message: String,
        errorCode: String,
        icon: ErrorOverlay.Icon = .generic,
        retryTitle: String = "Tải lại",
        secondaryTitle: String? = nil
    ) -> FeatureOverlayDescriptor {
        FeatureOverlayDescriptor(
            title: title,
            message: message,
            retryTitle: retryTitle,
            secondaryTitle: secondaryTitle,
            errorCode: errorCode,
            icon: icon,
            isLoading: false
        )
    }
}
