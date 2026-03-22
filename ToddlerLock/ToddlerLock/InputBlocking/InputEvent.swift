import CoreGraphics

/// Lightweight value type representing an input event captured by the event tap.
/// Designed to be stack-allocated with no heap allocation in the tap callback.
struct InputEvent {
    enum EventType: UInt8 {
        case keyDown
        case keyUp
        case flagsChanged
        case mouseMove
        case mouseDown
        case mouseUp
        case mouseDragged
        case rightMouseDown
        case rightMouseUp
        case scrollWheel
        case systemDefined  // volume, brightness, media keys
    }

    let type: EventType
    let keyCode: UInt16
    let characters: String?
    let position: CGPoint
    let delta: CGPoint          // mouse delta for disassociated cursor tracking
    let modifiers: CGEventFlags
    let timestamp: UInt64
    let scrollDeltaY: Double

    init(type: EventType,
         keyCode: UInt16 = 0,
         characters: String? = nil,
         position: CGPoint = .zero,
         delta: CGPoint = .zero,
         modifiers: CGEventFlags = [],
         timestamp: UInt64 = 0,
         scrollDeltaY: Double = 0) {
        self.type = type
        self.keyCode = keyCode
        self.characters = characters
        self.position = position
        self.delta = delta
        self.modifiers = modifiers
        self.timestamp = timestamp
        self.scrollDeltaY = scrollDeltaY
    }
}
