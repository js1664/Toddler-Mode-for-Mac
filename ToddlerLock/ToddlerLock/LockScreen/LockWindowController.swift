import AppKit
import SpriteKit

/// Creates and manages the borderless full-screen lock window(s).
/// One window per connected display. Main display hosts the SpriteKit scene;
/// secondary displays get a plain colored window.
final class LockWindowController {
    private var windows: [NSWindow] = []
    private(set) var mainViewController: LockViewController?

    /// Create lock windows covering all screens and show them.
    func showLockScreen(mode: PlayModeType = .freePlay) {
        closeAll()

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
    func handleDisplayChange(mode: PlayModeType = .freePlay) {
        // Re-create all windows for current screen configuration
        showLockScreen(mode: mode)
    }

    // MARK: - Private

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
