import Foundation
import CoreGraphics

/// Stores app settings in UserDefaults. Password stored separately (Keychain in Phase 4).
final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    // MARK: - Exit Shortcut

    var exitKeyCode: UInt16 {
        get { UInt16(defaults.integer(forKey: "exitKeyCode").nonZeroOr(53)) } // 53 = Escape
        set { defaults.set(Int(newValue), forKey: "exitKeyCode") }
    }

    var exitModifierFlags: UInt64 {
        get {
            let stored = defaults.integer(forKey: "exitModifierFlags")
            if stored == 0 {
                // Default: Command + Shift
                return CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue
            }
            return UInt64(stored)
        }
        set { defaults.set(Int(newValue), forKey: "exitModifierFlags") }
    }

    var exitModifiers: CGEventFlags {
        get { CGEventFlags(rawValue: exitModifierFlags) }
        set { exitModifierFlags = newValue.rawValue }
    }

    // MARK: - Password

    var passwordEnabled: Bool {
        get { defaults.bool(forKey: "passwordEnabled") }
        set { defaults.set(newValue, forKey: "passwordEnabled") }
    }

    /// For Phase 1, store password directly. Phase 4 moves this to Keychain.
    var password: String {
        get { defaults.string(forKey: "lockPassword") ?? "" }
        set { defaults.set(newValue, forKey: "lockPassword") }
    }

    // MARK: - Mode

    var selectedMode: PlayModeType {
        get {
            guard let raw = defaults.string(forKey: "selectedMode"),
                  let mode = PlayModeType(rawValue: raw) else {
                return .freePlay
            }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: "selectedMode") }
    }

    // MARK: - Sound

    var soundEnabled: Bool {
        get {
            if defaults.object(forKey: "soundEnabled") == nil { return true }
            return defaults.bool(forKey: "soundEnabled")
        }
        set { defaults.set(newValue, forKey: "soundEnabled") }
    }

    var musicEnabled: Bool {
        get { defaults.bool(forKey: "musicEnabled") }
        set { defaults.set(newValue, forKey: "musicEnabled") }
    }

    // MARK: - Character Set

    var characterSet: LetterCharacterSet {
        get {
            guard let raw = defaults.string(forKey: "characterSet"),
                  let cs = LetterCharacterSet(rawValue: raw) else {
                return .english
            }
            return cs
        }
        set { defaults.set(newValue.rawValue, forKey: "characterSet") }
    }

    private init() {}
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int {
        self == 0 ? fallback : self
    }
}
