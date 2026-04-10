import SpriteKit

/// The available play modes.
enum PlayModeType: String, CaseIterable {
    case freePlay = "Free Play"
    case game = "Game"
    case character = "Character"
    case chill = "Chill"
}

/// Protocol that all visual play modes conform to.
/// Each mode provides an SKScene and handles input events from the InputEventBus.
protocol PlayMode: AnyObject {
    /// The SpriteKit scene for this mode.
    var scene: SKScene { get }

    /// Handle a key down event.
    func handleKeyDown(keyCode: UInt16, characters: String?)

    /// Handle a key up event.
    func handleKeyUp(keyCode: UInt16)

    /// Handle mouse/cursor movement (virtual position after delta).
    func handleMouseMove(position: CGPoint)

    /// Handle mouse/cursor click.
    func handleMouseDown(position: CGPoint)

    /// Handle mouse drag.
    func handleMouseDragged(position: CGPoint)
}
