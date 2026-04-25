import CoreGraphics
import AppKit

/// Manages cursor hiding and pointer disassociation during lock mode.
/// When disassociated, the real pointer stops moving; we use mouse deltas
/// from the event tap to drive our custom cursor follower sprite.
///
/// IMPORTANT: CGDisplayHideCursor/CGDisplayShowCursor are reference-counted.
/// Every hide call must be balanced by exactly one show call. We track the
/// hide count to ensure perfect balance on deactivate.
final class CursorManager {
    static let shared = CursorManager()

    /// Current virtual cursor position (used by the CursorFollower sprite)
    private(set) var virtualPosition: CGPoint = .zero
    private var screenBounds: CGRect = .zero

    /// Whether we're currently in the activated (hidden) state
    private(set) var isActive = false

    /// Number of times we've called CGDisplayHideCursor beyond the initial one
    private var extraHideCount = 0

    /// Hide the system cursor and disassociate the pointer from mouse movement.
    func activate() {
        if let mainScreen = NSScreen.main {
            screenBounds = mainScreen.frame
            // Start virtual cursor at screen center (only on first activation)
            if !isActive {
                virtualPosition = CGPoint(
                    x: screenBounds.midX,
                    y: screenBounds.midY
                )
            }
        }

        if isActive {
            // Already hidden — don't increment the hide count again.
            // Just re-disassociate in case it was reset.
            CGAssociateMouseAndMouseCursorPosition(0)
            print("[CursorManager] Already active, re-disassociated pointer only")
            return
        }

        isActive = true
        extraHideCount = 0
        CGDisplayHideCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(0) // Disassociate: pointer stops moving
        print("[CursorManager] Cursor hidden and disassociated")
    }

    /// Show the system cursor and re-associate pointer movement.
    func deactivate() {
        guard isActive else {
            print("[CursorManager] Already inactive, skipping deactivate")
            return
        }

        isActive = false

        CGAssociateMouseAndMouseCursorPosition(1) // Re-associate

        // Show cursor once to balance our single hide call
        CGDisplayShowCursor(CGMainDisplayID())

        // Also force-show a few extra times to counteract any stale hide counts
        // from system sleep/wake or other edge cases. ShowCursor won't go
        // below 0 (it just clamps to visible), so extra calls are harmless.
        for _ in 0..<3 {
            CGDisplayShowCursor(CGMainDisplayID())
        }

        // Move the real cursor to screen center so it's immediately visible
        if let mainScreen = NSScreen.main {
            let centerX = mainScreen.frame.midX
            let centerY = mainScreen.frame.midY
            CGWarpMouseCursorPosition(CGPoint(x: centerX, y: centerY))
        }

        print("[CursorManager] Cursor shown and re-associated")
    }

    /// Update the virtual cursor position using mouse delta from the event tap.
    /// Returns the new virtual position clamped to screen bounds.
    @discardableResult
    func updatePosition(delta: CGPoint) -> CGPoint {
        virtualPosition.x += delta.x
        virtualPosition.y += delta.y

        // Clamp to screen bounds
        virtualPosition.x = max(screenBounds.minX, min(virtualPosition.x, screenBounds.maxX))
        virtualPosition.y = max(screenBounds.minY, min(virtualPosition.y, screenBounds.maxY))

        return virtualPosition
    }

    /// Update screen bounds when displays change.
    func updateScreenBounds() {
        if let mainScreen = NSScreen.main {
            screenBounds = mainScreen.frame
        }
    }
}
