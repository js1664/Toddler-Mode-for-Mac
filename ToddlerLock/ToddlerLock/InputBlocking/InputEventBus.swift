import Foundation
import CoreGraphics

/// Routing mode determines where input events are delivered.
enum InputRoutingMode {
    case animation   // Events go to the SpriteKit scene
    case password    // Events go to the password overlay
}

/// Thread-safe event bus that decouples the CGEventTap callback from event consumers.
/// The tap callback enqueues events from its thread; the main thread dequeues them.
final class InputEventBus {
    static let shared = InputEventBus()

    /// Current routing mode. Set from the main thread only.
    var routingMode: InputRoutingMode = .animation

    /// Callback invoked on the main thread for each event in animation mode.
    var onAnimationEvent: ((InputEvent) -> Void)?

    /// Callback invoked on the main thread for each event in password mode.
    var onPasswordEvent: ((InputEvent) -> Void)?

    /// Callback invoked on the main thread when the exit shortcut is detected.
    var onExitShortcut: (() -> Void)?

    private let queue = DispatchQueue(label: "com.toddlerlock.eventbus", qos: .userInteractive)

    private init() {}

    /// Called from the event tap callback thread. Must be fast and allocation-free
    /// (the DispatchQueue.main.async is the only allocation, which is acceptable).
    func enqueue(_ event: InputEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch self.routingMode {
            case .animation:
                self.onAnimationEvent?(event)
            case .password:
                self.onPasswordEvent?(event)
            }
        }
    }

    /// Called from the event tap callback when exit shortcut is detected.
    func signalExitShortcut() {
        DispatchQueue.main.async { [weak self] in
            self?.onExitShortcut?()
        }
    }
}
