import CoreGraphics
import AppKit

/// Manages cursor hiding and pointer disassociation during lock mode.
/// When disassociated, the real pointer stops moving; we use mouse deltas
/// from the event tap to drive our custom cursor follower sprite.
final class CursorManager {
    static let shared = CursorManager()

    /// Current virtual cursor position (used by the CursorFollower sprite)
    private(set) var virtualPosition: CGPoint = .zero
    private var screenBounds: CGRect = .zero

    /// Hide the system cursor and disassociate the pointer from mouse movement.
    func activate() {
        if let mainScreen = NSScreen.main {
            screenBounds = mainScreen.frame
            // Start virtual cursor at screen center
            virtualPosition = CGPoint(
                x: screenBounds.midX,
                y: screenBounds.midY
            )
        }

        CGDisplayHideCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(0) // Disassociate: pointer stops moving
        print("[CursorManager] Cursor hidden and disassociated")
    }

    /// Show the system cursor and re-associate pointer movement.
    func deactivate() {
        CGAssociateMouseAndMouseCursorPosition(1) // Re-associate
        CGDisplayShowCursor(CGMainDisplayID())
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
