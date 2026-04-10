import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Components

    private let eventTapManager = EventTapManager()
    private let presentationManager = PresentationManager()
    private let lockWindowController = LockWindowController()
    private let lifecycleManager = LifecycleManager()
    private let permissionChecker = PermissionChecker()
    private let cursorManager = CursorManager.shared
    private let eventBus = InputEventBus.shared
    private let settings = SettingsStore.shared

    // MARK: - Windows

    private var settingsWindow: NSWindow?
    private var passwordOverlay: PasswordOverlayView?

    // MARK: - State

    private var isLocked = false

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app shows as a regular app with dock icon and windows
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Request permissions on first launch
        if !permissionChecker.hasInputMonitoring {
            permissionChecker.requestInputMonitoring()
        }

        showSettingsWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return !isLocked // Only quit when not locked
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isLocked {
            // Prevent quitting while locked
            return .terminateCancel
        }
        return .terminateNow
    }

    // MARK: - Settings Window

    private func showSettingsWindow() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        var settingsView = SettingsView()
        settingsView.onLockNow = { [weak self] in
            self?.enterLockMode()
        }

        let hostingView = NSHostingView(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "Toddler Mode"
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    // MARK: - Lock Mode

    private func enterLockMode() {
        guard !isLocked else { return }

        // Probe permission before tearing down the UI. If the tap can't be created,
        // show a helpful alert and bail out cleanly rather than silently failing.
        if !permissionChecker.hasInputMonitoring {
            showPermissionAlert()
            return
        }

        isLocked = true

        // Configure the exit shortcut detector
        eventTapManager.shortcutDetector = ExitShortcutDetector(
            keyCode: settings.exitKeyCode,
            requiredModifiers: settings.exitModifiers
        )

        // Set up exit shortcut handler
        eventBus.onExitShortcut = { [weak self] in
            self?.handleExitShortcut()
        }

        // Apply sound settings
        SoundManager.shared.enabled = settings.soundEnabled
        SoundManager.shared.musicEnabled = settings.musicEnabled

        // Hide settings window
        settingsWindow?.orderOut(nil)

        // Show lock screen
        lockWindowController.showLockScreen(mode: settings.selectedMode)

        // Set up password overlay on the main lock view
        if let mainVC = lockWindowController.mainViewController, let window = mainVC.view.window {
            let overlay = PasswordOverlayView(frame: window.frame)
            overlay.isHidden = true
            // Password verified via KeychainManager in the overlay
            overlay.onUnlock = { [weak self] in
                self?.exitLockMode()
            }
            overlay.onCancel = { [weak self] in
                self?.dismissPasswordOverlay()
            }
            mainVC.view.addSubview(overlay)
            overlay.frame = mainVC.view.bounds
            overlay.autoresizingMask = [.width, .height]
            passwordOverlay = overlay

            // Route password events
            eventBus.onPasswordEvent = { [weak overlay] event in
                overlay?.handleKeyEvent(event)
            }
        }

        // Activate presentation options (hide dock, disable switching, etc.)
        presentationManager.activate()

        // Hide and disassociate cursor
        cursorManager.activate()

        // Start the event tap — this blocks all input
        let tapStarted = eventTapManager.start()
        if !tapStarted {
            print("[AppDelegate] ERROR: Event tap failed to start. Aborting lock.")
            exitLockMode()
            return
        }

        // Start lifecycle monitoring
        lifecycleManager.start(
            eventTapManager: eventTapManager,
            lockWindowController: lockWindowController,
            cursorManager: cursorManager
        )

        #if DEBUG
        lifecycleManager.onDebugAutoUnlock = { [weak self] in
            print("[AppDelegate] DEBUG: Auto-unlock triggered")
            self?.exitLockMode()
        }
        #endif

        // Start background music if enabled
        SoundManager.shared.startMusic()

        // Activate our app to ensure the lock window is frontmost
        NSApp.activate(ignoringOtherApps: true)

        print("[AppDelegate] Lock mode entered")
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Input Monitoring Permission Required"
        alert.informativeText = """
        Toddler Mode needs Input Monitoring permission to block keyboard and mouse input.

        In System Settings → Privacy & Security → Input Monitoring:
        1. Find Toddler Mode in the list (remove any old entries first)
        2. Toggle it ON
        3. Quit and relaunch Toddler Mode

        Note: each build of the app is treated separately by macOS, so the app you downloaded from GitHub needs its own permission grant — even if an older copy already had it.
        """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            permissionChecker.openInputMonitoringSettings()
        }
    }

    private func exitLockMode() {
        guard isLocked else { return }

        isLocked = false

        // Stop lifecycle monitoring
        lifecycleManager.stop()

        // Stop background music
        SoundManager.shared.stopMusic()

        // Stop the event tap
        eventTapManager.stop()

        // Restore presentation options
        presentationManager.deactivate()

        // Show and re-associate cursor
        cursorManager.deactivate()

        // Close lock windows
        lockWindowController.closeAll()
        passwordOverlay = nil

        // Clear event bus handlers
        eventBus.onAnimationEvent = nil
        eventBus.onPasswordEvent = nil
        eventBus.onExitShortcut = nil
        eventBus.routingMode = .animation

        // Show settings window
        showSettingsWindow()

        print("[AppDelegate] Lock mode exited")
    }

    // MARK: - Exit Shortcut Handling

    private func handleExitShortcut() {
        if settings.passwordEnabled && !settings.password.isEmpty {
            showPasswordOverlay()
        } else {
            exitLockMode()
        }
    }

    private func showPasswordOverlay() {
        eventBus.routingMode = .password
        passwordOverlay?.show()
    }

    private func dismissPasswordOverlay() {
        passwordOverlay?.hide()
        eventBus.routingMode = .animation
    }
}
