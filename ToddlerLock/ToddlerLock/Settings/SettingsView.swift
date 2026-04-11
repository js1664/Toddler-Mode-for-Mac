import SwiftUI

/// Settings view shown before locking. Compact, friendly layout.
struct SettingsView: View {
    @State private var selectedMode: PlayModeType = SettingsStore.shared.selectedMode
    @State private var exitKeyCode: UInt16 = SettingsStore.shared.exitKeyCode
    @State private var exitModifiers: CGEventFlags = SettingsStore.shared.exitModifiers
    @State private var passwordEnabled: Bool = SettingsStore.shared.passwordEnabled
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var soundEnabled: Bool = SettingsStore.shared.soundEnabled
    @State private var musicEnabled: Bool = SettingsStore.shared.musicEnabled
    @State private var characterSet: LetterCharacterSet = SettingsStore.shared.characterSet
    @State private var showPasswordError: Bool = false
    @State private var passwordErrorMessage: String = ""
    var onLockNow: (() -> Void)?

    private let modeEmoji: [PlayModeType: String] = [
        .freePlay: "🎨",
        .game: "🎮",
        .character: "🐾",
        .chill: "🌿"
    ]

    private let modeDescription: [PlayModeType: String] = [
        .freePlay: "Colorful letters, shapes & rainbow trails",
        .game: "Pop floating bubbles to score points",
        .character: "A friendly creature follows the mouse",
        .chill: "Gentle emoji & soft colors for calm play"
    ]

    var body: some View {
        VStack(spacing: 14) {
            // Header
            VStack(spacing: 2) {
                Text("Toddler Mode")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Let your kids play safely")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 18)

            // Play Mode — fun cards
            VStack(alignment: .leading, spacing: 8) {
                Text("Play Mode")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    ForEach(PlayModeType.allCases, id: \.self) { mode in
                        Button(action: { selectedMode = mode }) {
                            VStack(spacing: 4) {
                                Text(modeEmoji[mode] ?? "")
                                    .font(.system(size: 24))
                                Text(mode.rawValue)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedMode == mode
                                          ? Color.accentColor.opacity(0.15)
                                          : Color.gray.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedMode == mode
                                            ? Color.accentColor
                                            : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(modeDescription[selectedMode] ?? "")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 24)

            // Options in rounded card
            GroupBox {
                VStack(spacing: 10) {
                    // Characters + Sound side by side
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Letters", systemImage: "textformat")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            Picker("Character Set", selection: $characterSet) {
                                ForEach(LetterCharacterSet.allCases, id: \.self) { cs in
                                    Text(cs.rawValue).tag(cs)
                                }
                            }
                            .labelsHidden()
                            .controlSize(.small)
                            Text(characterSet.characters.prefix(6).joined(separator: " "))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            Label("Sound", systemImage: "speaker.wave.2")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            Toggle("Sound effects", isOn: $soundEnabled)
                                .toggleStyle(.checkbox)
                                .controlSize(.small)
                            Toggle("Background music", isOn: $musicEnabled)
                                .toggleStyle(.checkbox)
                                .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    // Exit Shortcut + Password side by side
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Exit Shortcut", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            ShortcutRecorderView(keyCode: $exitKeyCode, modifiers: $exitModifiers)
                                .frame(height: 26)
                            Text("Requires 2+ modifiers")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            Label("Password", systemImage: "key")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            Toggle("Require to unlock", isOn: $passwordEnabled)
                                .toggleStyle(.checkbox)
                                .controlSize(.small)
                            if passwordEnabled {
                                SecureField("Password", text: $password)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                    .frame(maxWidth: 150)
                                SecureField("Confirm", text: $confirmPassword)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                    .frame(maxWidth: 150)
                                if showPasswordError {
                                    Text(passwordErrorMessage)
                                        .font(.system(size: 10))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(4)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Lock Button
            VStack(spacing: 6) {
                Button(action: lockNow) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                        Text("Lock Now")
                    }
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)

                #if DEBUG
                Text("DEBUG: Auto-unlock after 60 seconds")
                    .font(.caption2)
                    .foregroundColor(.orange)
                #endif
            }
            .padding(.bottom, 16)
        }
        .frame(width: 480, height: 500)
    }

    private func lockNow() {
        // Save settings
        SettingsStore.shared.selectedMode = selectedMode
        SettingsStore.shared.soundEnabled = soundEnabled
        SettingsStore.shared.musicEnabled = musicEnabled
        SettingsStore.shared.characterSet = characterSet
        SettingsStore.shared.exitKeyCode = exitKeyCode
        SettingsStore.shared.exitModifiers = exitModifiers
        SettingsStore.shared.passwordEnabled = passwordEnabled

        if passwordEnabled {
            guard !password.isEmpty else {
                showPasswordError = true
                passwordErrorMessage = "Password cannot be empty"
                return
            }
            guard password == confirmPassword else {
                showPasswordError = true
                passwordErrorMessage = "Passwords don't match"
                return
            }
            KeychainManager.savePassword(password)
        }

        showPasswordError = false
        onLockNow?()
    }
}
