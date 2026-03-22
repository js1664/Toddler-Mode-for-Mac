import CoreGraphics

/// Stateless detector that checks if a CGEvent matches the configured exit shortcut.
/// Default shortcut: Command + Shift + Escape
struct ExitShortcutDetector {
    /// The key code for the exit shortcut (default: 53 = Escape)
    var keyCode: UInt16 = 53

    /// Required modifier flags (default: Command + Shift)
    var requiredModifiers: CGEventFlags = [.maskCommand, .maskShift]

    /// Checks if the given event matches the exit shortcut.
    /// This is called from the event tap callback and must be extremely fast.
    func matches(eventKeyCode: UInt16, eventModifiers: CGEventFlags) -> Bool {
        guard eventKeyCode == keyCode else { return false }

        // Check that all required modifiers are present.
        // We mask out device-dependent bits and only compare the modifier flags we care about.
        let relevantMask: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
        let eventMods = eventModifiers.intersection(relevantMask)
        let requiredMods = requiredModifiers.intersection(relevantMask)

        return eventMods == requiredMods
    }
}
