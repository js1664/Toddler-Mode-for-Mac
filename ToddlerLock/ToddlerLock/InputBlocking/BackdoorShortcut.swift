import CoreGraphics

/// Always-available emergency unlock for parents who forget their custom shortcut or password.
///
/// Press the backdoor shortcut to bring up the password overlay, then enter the backdoor PIN.
/// This works regardless of user settings — it's a permanent escape hatch.
///
/// Documented publicly on suss.dev/toddlermodemac so parents can always look it up.
/// Toddlers physically cannot press 4 modifier keys + a letter simultaneously.
enum BackdoorShortcut {
    /// Key code for "P" (kVK_ANSI_P)
    static let keyCode: UInt16 = 35

    /// Required modifiers: Cmd + Shift + Ctrl + Option (all four)
    static let requiredModifiers: CGEventFlags = [
        .maskCommand,
        .maskShift,
        .maskControl,
        .maskAlternate,
    ]

    /// PIN required after the shortcut is pressed.
    static let pin: String = "0000"

    /// Human-readable description for UI/website.
    static let displayShortcut: String = "⌘ ⇧ ⌃ ⌥ P"

    /// Check if a key event matches the backdoor shortcut.
    static func matches(eventKeyCode: UInt16, eventModifiers: CGEventFlags) -> Bool {
        guard eventKeyCode == keyCode else { return false }
        let mask: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
        return eventModifiers.intersection(mask) == requiredModifiers.intersection(mask)
    }
}
