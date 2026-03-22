import SwiftUI

/// Settings view shown before locking. Allows configuration of mode, shortcut, password.
struct SettingsView: View {
    @State private var selectedMode: PlayModeType = SettingsStore.shared.selectedMode
    @State private var passwordEnabled: Bool = SettingsStore.shared.passwordEnabled
    @State private var password: String = SettingsStore.shared.password
    @State private var confirmPassword: String = ""
    @State private var soundEnabled: Bool = SettingsStore.shared.soundEnabled
    @State private var showPasswordError: Bool = false
    @State private var permissionGranted: Bool = false

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
                    HStack {
                        Text("Shortcut:")
                        Spacer()
                        Text(shortcutDisplayString())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                    }
                    Text("Press this key combination to exit lock mode")
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
                            Text("Passwords don't match")
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
                        Image(systemName: permissionChecker.hasInputMonitoring ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(permissionChecker.hasInputMonitoring ? .green : .orange)
                        Text("Input Monitoring")
                        Spacer()
                        if !permissionChecker.hasInputMonitoring {
                            Button("Grant") {
                                permissionChecker.requestInputMonitoring()
                                permissionChecker.openInputMonitoringSettings()
                            }
                        } else {
                            Text("Granted").foregroundColor(.secondary)
                        }
                    }
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
        .frame(width: 500, height: 620)
        .onAppear {
            checkPermissions()
            // Poll permissions every 2 seconds
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                checkPermissions()
            }
        }
    }

    private func checkPermissions() {
        permissionGranted = permissionChecker.allPermissionsGranted
    }

    private func lockNow() {
        // Save settings
        SettingsStore.shared.selectedMode = selectedMode
        SettingsStore.shared.soundEnabled = soundEnabled
        SettingsStore.shared.passwordEnabled = passwordEnabled

        if passwordEnabled {
            guard password == confirmPassword, !password.isEmpty else {
                showPasswordError = true
                return
            }
            SettingsStore.shared.password = password
        }

        showPasswordError = false
        onLockNow?()
    }

    private func shortcutDisplayString() -> String {
        let store = SettingsStore.shared
        var parts: [String] = []
        let mods = store.exitModifiers
        if mods.contains(.maskCommand) { parts.append("\u{2318}") }
        if mods.contains(.maskShift) { parts.append("\u{21E7}") }
        if mods.contains(.maskControl) { parts.append("\u{2303}") }
        if mods.contains(.maskAlternate) { parts.append("\u{2325}") }

        // Key name
        switch store.exitKeyCode {
        case 53: parts.append("Esc")
        case 36: parts.append("Return")
        case 49: parts.append("Space")
        default: parts.append("Key \(store.exitKeyCode)")
        }

        return parts.joined(separator: "")
    }
}
