import Foundation
import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter` for local crash/restart notifications. Authorization
/// is requested lazily the first time we actually want to post, so users aren't prompted on launch.
@MainActor
final class Notifier {
    private var authorized = false
    private var requested = false

    /// Post when the watchdog restarts a container.
    func containerRestarted(name: String, attempt: Int, enabled: Bool) {
        guard enabled else { return }
        post(title: AppText.notificationContainerRestartedTitle,
             body: AppText.notificationContainerRestartedBody(name: name, attempt: attempt))
    }

    /// Post when a container exits unexpectedly and no restart policy applies.
    func containerExited(name: String, enabled: Bool) {
        guard enabled else { return }
        post(title: AppText.notificationContainerStoppedTitle,
             body: AppText.notificationContainerStoppedBody(name))
    }

    /// Post when an app-managed healthcheck flips a container to unhealthy.
    func containerUnhealthy(name: String, enabled: Bool) {
        guard enabled else { return }
        post(title: AppText.notificationContainerUnhealthyTitle,
             body: AppText.notificationContainerUnhealthyBody(name))
    }

    private func post(title: String, body: String) {
        Task { [weak self] in
            guard let self, await self.ensureAuthorized() else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func ensureAuthorized() async -> Bool {
        if authorized { return true }
        guard !requested else { return authorized }
        requested = true
        let center = UNUserNotificationCenter.current()
        authorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        return authorized
    }
}
