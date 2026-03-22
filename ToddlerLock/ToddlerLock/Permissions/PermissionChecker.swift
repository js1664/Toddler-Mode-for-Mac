import CoreGraphics
import AppKit

/// Checks and requests the permissions needed for the event tap.
/// Currently requires Input Monitoring. Accessibility is tested but may not be needed.
final class PermissionChecker {
    /// Whether Input Monitoring permission is granted.
    var hasInputMonitoring: Bool {
        CGPreflightListenEventAccess()
    }

    /// Request Input Monitoring permission. Shows the system prompt.
    /// Returns true if already granted, false if the user needs to grant it.
    @discardableResult
    func requestInputMonitoring() -> Bool {
        if hasInputMonitoring { return true }
        // This triggers the system permission dialog
        CGRequestListenEventAccess()
        return false
    }

    /// Whether Accessibility permission is granted.
    /// We check this to determine if it's needed for the defaultTap option.
    var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Request Accessibility permission by prompting the system dialog.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Whether all required permissions are granted.
    var allPermissionsGranted: Bool {
        // Start with Input Monitoring only. If testing shows Accessibility
        // is also required, add it here.
        hasInputMonitoring
    }

    /// Open System Settings to the appropriate privacy pane.
    func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
