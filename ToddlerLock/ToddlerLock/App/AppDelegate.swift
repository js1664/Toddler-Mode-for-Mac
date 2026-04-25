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

    // MARK: - Menu Bar

    private var statusItem: NSStatusItem?

    // MARK: - State

    private var isLocked = false
    private var displayChangeObserver: NSObjectProtocol?

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app shows as a regular app with dock icon and windows
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Set up the main menu (enables Cmd+Q, Cmd+W, etc.)
        setupMainMenu()

        // Set up the menu bar status item
        setupStatusItem()

        showSettingsWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running for the status item
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isLocked {
            return .terminateCancel
        }
        return .terminateNow
    }

    // MARK: - Main Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Toddler Mode", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdatesAction), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(showSettingsAction), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Toddler Mode", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Toddler Mode", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func showSettingsAction() {
        showSettingsWindow()
    }

    @objc private func checkForUpdatesAction() {
        UpdateManager.shared.checkForUpdates()
    }

    // MARK: - Status Item (Menu Bar Icon)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            // Use the app icon for the menu bar, scaled to 18x18
            if let appIcon = NSImage(named: "AppIcon") {
                let resized = NSImage(size: NSSize(width: 18, height: 18))
                resized.lockFocus()
                appIcon.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
                resized.unlockFocus()
                resized.isTemplate = false
                button.image = resized
            } else {
                button.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Toddler Mode")
            }
        }
        updateStatusMenu()
    }

    private func updateStatusMenu() {
        let menu = NSMenu()
        if isLocked {
            let lockedItem = menu.addItem(withTitle: "Locked", action: nil, keyEquivalent: "")
            lockedItem.isEnabled = false
        } else {
            menu.addItem(withTitle: "Lock Now", action: #selector(lockFromMenu), keyEquivalent: "l")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Settings...", action: #selector(showSettingsAction), keyEquivalent: "")
            menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdatesAction), keyEquivalent: "")
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem?.menu = menu
    }

    @objc private func lockFromMenu() {
        enterLockMode()
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
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
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

        isLocked = true
        updateStatusMenu()

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
        setupPasswordOverlay()

        // Observe display changes so we can re-attach the password overlay
        // when windows are rebuilt by LockWindowController
        displayChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Small delay to let LockWindowController rebuild first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.setupPasswordOverlay()
            }
        }

        // Activate presentation options (hide dock, disable switching, etc.)
        presentationManager.activate()

        // Hide and disassociate cursor
        cursorManager.activate()

        // Start the event tap — this blocks all input
        let tapStarted = eventTapManager.start()
        if !tapStarted {
            print("[AppDelegate] ERROR: Event tap failed to start.")
            exitLockMode()
            showPermissionAlert()
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
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        Toddler Mode needs Accessibility permission to block keyboard and mouse input.

        In System Settings → Privacy & Security → Accessibility:
        1. Find Toddler Mode in the list
        2. Toggle it ON
        3. Quit and relaunch Toddler Mode
        """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            permissionChecker.openAccessibilitySettings()
        }
    }

    private func exitLockMode() {
        guard isLocked else { return }

        isLocked = false
        updateStatusMenu()

        // Remove display change observer
        if let observer = displayChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            displayChangeObserver = nil
        }

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

    // MARK: - Password Overlay

    /// Set up (or re-set up) the password overlay on the current main lock view.
    /// Called on initial lock and again after display changes rebuild the windows.
    private func setupPasswordOverlay() {
        guard let mainVC = lockWindowController.mainViewController,
              let window = mainVC.view.window else { return }

        // Remove old overlay if it's attached to a different view hierarchy
        passwordOverlay?.removeFromSuperview()

        let overlay = PasswordOverlayView(frame: window.frame)
        overlay.isHidden = true
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

        eventBus.onPasswordEvent = { [weak overlay] event in
            overlay?.handleKeyEvent(event)
        }
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
