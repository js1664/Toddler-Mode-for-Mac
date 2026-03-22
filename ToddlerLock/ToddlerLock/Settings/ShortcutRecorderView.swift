import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A view that captures a keyboard shortcut combination.
/// Click to start recording, then press your desired key combo.
struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var keyCode: UInt16
    @Binding var modifiers: CGEventFlags

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.keyCode = keyCode
        view.modifiers = modifiers
        view.onShortcutChanged = { newKeyCode, newModifiers in
            keyCode = newKeyCode
            modifiers = newModifiers
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.keyCode = keyCode
        nsView.modifiers = modifiers
        nsView.updateDisplay()
    }
}

/// The underlying NSView that handles key event capture.
class ShortcutRecorderNSView: NSView {
    var keyCode: UInt16 = 53
    var modifiers: CGEventFlags = [.maskCommand, .maskShift]
    var onShortcutChanged: ((UInt16, CGEventFlags) -> Void)?

    private var isRecording = false
    private let label = NSTextField(labelWithString: "")
    private let recordButton = NSButton()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        label.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        recordButton.title = "Record"
        recordButton.bezelStyle = .rounded
        recordButton.target = self
        recordButton.action = #selector(toggleRecording)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(recordButton)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            recordButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            recordButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            recordButton.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),

            heightAnchor.constraint(equalToConstant: 30),
        ])

        updateDisplay()
    }

    override var acceptsFirstResponder: Bool { true }

    @objc private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        recordButton.title = "Stop"
        label.stringValue = "Press shortcut..."
        label.textColor = .systemOrange
        window?.makeFirstResponder(self)
    }

    private func stopRecording() {
        isRecording = false
        recordButton.title = "Record"
        updateDisplay()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let newKeyCode = event.keyCode

        // Build modifier flags from NSEvent to CGEventFlags
        var newModifiers: CGEventFlags = []
        if event.modifierFlags.contains(.command) { newModifiers.insert(.maskCommand) }
        if event.modifierFlags.contains(.shift) { newModifiers.insert(.maskShift) }
        if event.modifierFlags.contains(.control) { newModifiers.insert(.maskControl) }
        if event.modifierFlags.contains(.option) { newModifiers.insert(.maskAlternate) }

        // Require at least 2 modifiers to prevent accidental exit by toddler
        let modCount = [
            newModifiers.contains(.maskCommand),
            newModifiers.contains(.maskShift),
            newModifiers.contains(.maskControl),
            newModifiers.contains(.maskAlternate),
        ].filter { $0 }.count

        guard modCount >= 2 else {
            label.stringValue = "Need 2+ modifiers!"
            label.textColor = .systemRed
            return
        }

        keyCode = newKeyCode
        modifiers = newModifiers
        onShortcutChanged?(newKeyCode, newModifiers)
        stopRecording()
    }

    func updateDisplay() {
        label.stringValue = shortcutString(keyCode: keyCode, modifiers: modifiers)
        label.textColor = .labelColor
    }

    private func shortcutString(keyCode: UInt16, modifiers: CGEventFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.maskControl) { parts.append("\u{2303}") }
        if modifiers.contains(.maskAlternate) { parts.append("\u{2325}") }
        if modifiers.contains(.maskShift) { parts.append("\u{21E7}") }
        if modifiers.contains(.maskCommand) { parts.append("\u{2318}") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    private func keyName(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Escape: return "Esc"
        case kVK_Return: return "Return"
        case kVK_Space: return "Space"
        case kVK_Delete: return "Delete"
        case kVK_Tab: return "Tab"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_UpArrow: return "\u{2191}"
        case kVK_DownArrow: return "\u{2193}"
        case kVK_LeftArrow: return "\u{2190}"
        case kVK_RightArrow: return "\u{2192}"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        default: return "Key\(keyCode)"
        }
    }
}
