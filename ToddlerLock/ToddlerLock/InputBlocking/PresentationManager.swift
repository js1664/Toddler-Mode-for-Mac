import AppKit

/// Manages NSApplication.PresentationOptions to hide system UI and block system-level actions.
/// This is the second layer of defense after the CGEventTap.
final class PresentationManager {
    private var previousOptions: NSApplication.PresentationOptions = []

    /// Activate kiosk-style presentation: hide dock/menu, disable process switching, force quit, etc.
    func activate() {
        let app = NSApplication.shared
        previousOptions = app.presentationOptions

        var options: NSApplication.PresentationOptions = [
            .hideDock,                    // Required for disableProcessSwitching
            .hideMenuBar,
            .disableProcessSwitching,     // Blocks Command-Tab, Mission Control switching
            .disableSessionTermination,   // Blocks logout
            .disableHideApplication,      // Blocks Command-H
            .disableAppleMenu,
            .disableMenuBarTransparency,
        ]

        #if !DEBUG
        // Only disable Force Quit in release builds — keep it available during development
        options.insert(.disableForceQuit)
        #endif

        do {
            try ObjC.catchException {
                app.presentationOptions = options
            }
            print("[PresentationManager] Activated kiosk presentation options")
        } catch {
            // If the full set fails, try a reduced set
            print("[PresentationManager] Full options failed: \(error). Trying reduced set.")
            let reduced: NSApplication.PresentationOptions = [
                .hideDock,
                .hideMenuBar,
                .disableProcessSwitching,
            ]
            app.presentationOptions = reduced
            print("[PresentationManager] Activated reduced presentation options")
        }
    }

    /// Restore normal presentation.
    func deactivate() {
        NSApplication.shared.presentationOptions = previousOptions
        print("[PresentationManager] Restored normal presentation options")
    }
}

// MARK: - ObjC exception catcher

/// Helper to catch Objective-C exceptions from AppKit APIs that throw (not Swift errors).
enum ObjC {
    static func catchException(_ block: () -> Void) throws {
        // In production, we'd use an ObjC helper to catch NSException.
        // For now, just run the block directly — if it throws, we'll handle the crash.
        block()
    }
}
