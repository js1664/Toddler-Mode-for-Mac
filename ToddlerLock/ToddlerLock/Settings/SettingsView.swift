import SwiftUI

/// Settings view shown before locking. Allows configuration of mode, shortcut, password.
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
    @State private var hasInputMonitoring: Bool = PermissionChecker().hasInputMonitoring
    @State private var hasAccessibility: Bool = PermissionChecker().hasAccessibility

    private let pollTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    let permissionChecker = PermissionChecker()
    var onLockNow: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Toddler Mode")
                    .font(.system(size: 36, weight: .bold))
                Text("Let your kids play safely")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 30)
            .padding(.bottom, 20)

            Form {
                // Mode Selection
                Section("Play Mode") {
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(PlayModeType.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Exit Shortcut
                Section("Exit Shortcut") {
                    ShortcutRecorderView(keyCode: $exitKeyCode, modifiers: $exitModifiers)
                        .frame(height: 30)
                    Text("Click Record, then press your desired shortcut (requires 2+ modifiers)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Password
                Section("Password Protection") {
                    Toggle("Require password to unlock", isOn: $passwordEnabled)

                    if passwordEnabled {
                        SecureField("Password", text: $password)
                        SecureField("Confirm Password", text: $confirmPassword)
                        if showPasswordError {
                            Text(passwordErrorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                // Characters
                Section("Letters") {
                    Picker("Character Set", selection: $characterSet) {
                        ForEach(LetterCharacterSet.allCases, id: \.self) { cs in
                            Text(cs.rawValue).tag(cs)
                        }
                    }
                    Text("Preview: \(characterSet.characters.prefix(8).joined(separator: " "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Sound
                Section("Sound") {
                    Toggle("Enable sound effects", isOn: $soundEnabled)
                    Toggle("Background music", isOn: $musicEnabled)
                }

                // Permissions
                Section("Permissions") {
                    HStack {
                        Image(systemName: hasInputMonitoring ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(hasInputMonitoring ? .green : .orange)
                        Text("Input Monitoring")
                        Spacer()
                        if !hasInputMonitoring {
                            Button("Open Settings") {
                                permissionChecker.openInputMonitoringSettings()
                            }
                        } else {
                            Text("Granted").foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Image(systemName: hasAccessibility ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(hasAccessibility ? .green : .orange)
                        Text("Accessibility")
                        Spacer()
                        if !hasAccessibility {
                            Button("Grant") {
                                permissionChecker.requestAccessibility()
                            }
                        } else {
                            Text("Granted").foregroundColor(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: .infinity)

            // Lock Button
            VStack(spacing: 8) {
                Button(action: lockNow) {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("Lock Now")
                    }
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                #if DEBUG
                Text("DEBUG: Auto-unlock after 60 seconds")
                    .font(.caption)
                    .foregroundColor(.orange)
                #endif
            }
            .padding(20)
        }
        .frame(width: 500, height: 650)
        .onReceive(pollTimer) { _ in
            hasInputMonitoring = permissionChecker.hasInputMonitoring
            hasAccessibility = permissionChecker.hasAccessibility
        }
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
