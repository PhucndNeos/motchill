import SwiftUI

struct FeatureStateOverlay: View {
    let descriptor: FeatureOverlayDescriptor
    let onRetry: () -> Void
    let onSecondary: (() -> Void)?

    init(
        descriptor: FeatureOverlayDescriptor,
        onRetry: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil
    ) {
        self.descriptor = descriptor
        self.onRetry = onRetry
        self.onSecondary = onSecondary
    }

    var body: some View {
        ErrorOverlay(
            title: descriptor.title,
            message: descriptor.message,
            retryTitle: descriptor.retryTitle,
            homeTitle: descriptor.secondaryTitle ?? "Go back",
            errorCode: descriptor.errorCode,
            icon: descriptor.icon,
            isLoading: descriptor.isLoading,
            onRetry: onRetry,
            onGoHome: onSecondary
        )
    }
}
