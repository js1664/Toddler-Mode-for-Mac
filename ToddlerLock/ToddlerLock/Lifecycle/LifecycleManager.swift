import AppKit
import CoreGraphics

/// Handles lifecycle events that can break the lock: sleep/wake, display changes,
/// permission revocation, tap health, and app deactivation.
final class LifecycleManager {
    private var eventTapManager: EventTapManager?
    private var lockWindowController: LockWindowController?
    private var cursorManager: CursorManager?
    private var permissionCheckTimer: Timer?
    private var tapHealthTimer: Timer?

    #if DEBUG
    private var debugAutoUnlockTimer: Timer?
    var onDebugAutoUnlock: (() -> Void)?
    #endif

    /// Start monitoring lifecycle events.
    func start(
        eventTapManager: EventTapManager,
        lockWindowController: LockWindowController,
        cursorManager: CursorManager
    ) {
        self.eventTapManager = eventTapManager
        self.lockWindowController = lockWindowController
        self.cursorManager = cursorManager

        let ws = NSWorkspace.shared.notificationCenter
        let nc = NotificationCenter.default

        // Sleep/wake
        ws.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(handleSleep), name: NSWorkspace.willSleepNotification, object: nil)

        // Display hotplug
        nc.addObserver(self, selector: #selector(handleScreenChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // App deactivation (another app somehow came to front)
        nc.addObserver(self, selector: #selector(handleDeactivation), name: NSApplication.didResignActiveNotification, object: nil)

        // Permission check: poll every 5 seconds
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }

        // Tap health check: poll every 2 seconds
        tapHealthTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkTapHealth()
        }

        #if DEBUG
        // Auto-unlock after 60 seconds in debug builds
        debugAutoUnlockTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            print("[LifecycleManager] DEBUG: Auto-unlock timer fired")
            self?.onDebugAutoUnlock?()
        }
        print("[LifecycleManager] DEBUG: Auto-unlock timer set for 60 seconds")
        #endif

        print("[LifecycleManager] Started monitoring lifecycle events")
    }

    /// Stop monitoring lifecycle events.
    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        tapHealthTimer?.invalidate()
        tapHealthTimer = nil

        #if DEBUG
        debugAutoUnlockTimer?.invalidate()
        debugAutoUnlockTimer = nil
        #endif

        eventTapManager = nil
        lockWindowController = nil
        cursorManager = nil

        print("[LifecycleManager] Stopped monitoring lifecycle events")
    }

    // MARK: - Sleep/Wake

    @objc private func handleSleep() {
        print("[LifecycleManager] System going to sleep")
        // Nothing to do — the tap will be re-verified on wake
    }

    @objc private func handleWake() {
        print("[LifecycleManager] System woke up — verifying lock state")

        // Small delay to let the system settle after wake
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // Re-enable tap if it was disabled during sleep
            if let tapManager = self.eventTapManager, !tapManager.isTapEnabled {
                print("[LifecycleManager] Tap was disabled during sleep, re-enabling")
                tapManager.reEnable()
            }

            // Bring lock windows to front (don't recreate — just re-order)
            self.lockWindowController?.bringToFront()

            // Re-disassociate cursor if needed (activate() is idempotent now —
            // it won't double-hide thanks to the isActive guard)
            self.cursorManager?.activate()

            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Display Changes

    @objc private func handleScreenChange() {
        print("[LifecycleManager] Screen configuration changed")
        cursorManager?.updateScreenBounds()
        lockWindowController?.handleDisplayChange()
    }

    // MARK: - App Deactivation

    @objc private func handleDeactivation() {
        print("[LifecycleManager] App deactivated — re-activating")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.lockWindowController?.bringToFront()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Permission Monitoring

    private func checkPermissions() {
        if !AXIsProcessTrusted() {
            print("[LifecycleManager] WARNING: Accessibility permission revoked!")
        }
    }

    // MARK: - Tap Health

    private func checkTapHealth() {
        guard let tapManager = eventTapManager else { return }
        if tapManager.isRunning && !tapManager.isTapEnabled {
            print("[LifecycleManager] Tap found disabled — re-enabling")
            tapManager.reEnable()
        }
    }
}
