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
    @State private var showPasswordError: Bool = false
    @State private var passwordErrorMessage: String = ""

    let permissionChecker = PermissionChecker()
    var onLockNow: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Toddler Lock")
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

                // Sound
                Section("Sound") {
                    Toggle("Enable sound effects", isOn: $soundEnabled)
                }

                // Permissions
                Section("Permissions") {
                    HStack {
                        Image(systemName: permissionChecker.hasAccessibility ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(permissionChecker.hasAccessibility ? .green : .orange)
                        Text("Accessibility")
                        Spacer()
                        if !permissionChecker.hasAccessibility {
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
    }

    private func lockNow() {
        // Save settings
        SettingsStore.shared.selectedMode = selectedMode
        SettingsStore.shared.soundEnabled = soundEnabled
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
