import CoreGraphics
import AppKit

/// Checks and requests the permissions needed for the event tap.
/// Accessibility permission is the only requirement — it allows CGEventTap
/// to intercept keyboard and mouse events at the system level.
final class PermissionChecker {
    /// Whether Accessibility permission is granted.
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
        hasAccessibility
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
