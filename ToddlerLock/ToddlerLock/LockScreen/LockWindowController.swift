import AppKit
import SpriteKit

/// Creates and manages the borderless full-screen lock window(s).
/// One window per connected display. Main display hosts the SpriteKit scene;
/// secondary displays get a plain colored window.
final class LockWindowController {
    private var windows: [NSWindow] = []
    private(set) var mainViewController: LockViewController?

    /// The mode that was used to create the lock screen. Remembered so display
    /// change events can recreate windows with the correct mode (not the default).
    private(set) var activeMode: PlayModeType = .freePlay

    /// Snapshot of screen IDs the last time we built windows, used to skip
    /// no-op display change notifications.
    private var lastScreenIDs: Set<UInt32> = []

    /// Create lock windows covering all screens and show them.
    func showLockScreen(mode: PlayModeType = .freePlay) {
        closeAll()

        activeMode = mode
        lastScreenIDs = currentScreenIDs()

        for screen in NSScreen.screens {
            let isMain = (screen == NSScreen.main)
            let window = createLockWindow(for: screen, isMain: isMain, mode: mode)
            windows.append(window)

            if isMain {
                mainViewController = window.contentViewController as? LockViewController
            }
        }
    }

    /// Close all lock windows.
    func closeAll() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        mainViewController = nil
    }

    /// Update windows when displays change (hotplug).
    /// Uses the stored activeMode — never resets to a hardcoded default.
    func handleDisplayChange() {
        let newIDs = currentScreenIDs()

        // If the set of screens hasn't actually changed, just resize existing
        // windows to match any new frames (e.g. resolution change) instead of
        // tearing everything down. This avoids the desktop flash.
        if newIDs == lastScreenIDs {
            resizeExistingWindows()
            return
        }

        // Screens actually changed — rebuild atomically: create new windows
        // first, then remove old ones, so the desktop is never exposed.
        let oldWindows = windows
        windows = []
        mainViewController = nil
        lastScreenIDs = newIDs

        for screen in NSScreen.screens {
            let isMain = (screen == NSScreen.main)
            let window = createLockWindow(for: screen, isMain: isMain, mode: activeMode)
            windows.append(window)

            if isMain {
                mainViewController = window.contentViewController as? LockViewController
            }
        }

        // Now close the old windows (they're behind the new ones)
        for window in oldWindows {
            window.orderOut(nil)
            window.close()
        }

        print("[LockWindowController] Display change: rebuilt windows for mode \(activeMode.rawValue)")
    }

    /// Re-order all lock windows to the front.
    func bringToFront() {
        for window in windows {
            window.orderFrontRegardless()
        }
        if let mainWindow = mainViewController?.view.window {
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Private

    private func currentScreenIDs() -> Set<UInt32> {
        Set(NSScreen.screens.compactMap {
            $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
        })
    }

    /// Resize existing windows to match current screen frames without
    /// tearing them down. Prevents the desktop flash on resolution changes.
    private func resizeExistingWindows() {
        let screens = NSScreen.screens
        // If the count is different somehow, fall back to full rebuild
        guard windows.count == screens.count else {
            let oldWindows = windows
            windows = []
            mainViewController = nil

            for screen in screens {
                let isMain = (screen == NSScreen.main)
                let window = createLockWindow(for: screen, isMain: isMain, mode: activeMode)
                windows.append(window)
                if isMain {
                    mainViewController = window.contentViewController as? LockViewController
                }
            }

            for window in oldWindows {
                window.orderOut(nil)
                window.close()
            }
            return
        }

        // Resize each window to its corresponding screen
        for (window, screen) in zip(windows, screens) {
            window.setFrame(screen.frame, display: true)
        }
        print("[LockWindowController] Display change: resized existing windows")
    }

    private func createLockWindow(for screen: NSScreen, isMain: Bool, mode: PlayModeType) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        // Window level above everything
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))

        // Collection behavior: present on all spaces, don't appear in window switcher
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]

        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.isReleasedWhenClosed = false

        if isMain {
            let viewController = LockViewController()
            viewController.currentMode = mode
            window.contentViewController = viewController
        } else {
            // Secondary display: plain dark view
            let view = NSView(frame: screen.frame)
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.black.cgColor
            window.contentView = view
        }

        window.setFrame(screen.frame, display: true)
        window.makeKeyAndOrderFront(nil)

        return window
    }
}
