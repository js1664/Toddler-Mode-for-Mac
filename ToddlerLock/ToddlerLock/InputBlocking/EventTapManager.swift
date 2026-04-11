import CoreGraphics
import Foundation

/// Manages the CGEventTap that intercepts all keyboard/mouse events at the system level.
/// The callback does minimal work: check shortcut, create InputEvent, enqueue, return nil.
final class EventTapManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    let eventBus = InputEventBus.shared
    var shortcutDetector = ExitShortcutDetector()

    /// Whether the tap is currently active
    var isRunning: Bool { eventTap != nil }

    /// Start intercepting all input events.
    /// Returns false if the tap could not be created (permissions missing).
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        // Event mask covering all input types we need to intercept.
        // Built incrementally to avoid compiler type-check timeout.
        var eventMask: CGEventMask = 0
        eventMask |= (1 << CGEventType.keyDown.rawValue)
        eventMask |= (1 << CGEventType.keyUp.rawValue)
        eventMask |= (1 << CGEventType.flagsChanged.rawValue)
        eventMask |= (1 << CGEventType.leftMouseDown.rawValue)
        eventMask |= (1 << CGEventType.leftMouseUp.rawValue)
        eventMask |= (1 << CGEventType.leftMouseDragged.rawValue)
        eventMask |= (1 << CGEventType.rightMouseDown.rawValue)
        eventMask |= (1 << CGEventType.rightMouseUp.rawValue)
        eventMask |= (1 << CGEventType.rightMouseDragged.rawValue)
        eventMask |= (1 << CGEventType.otherMouseDown.rawValue)
        eventMask |= (1 << CGEventType.otherMouseUp.rawValue)
        eventMask |= (1 << CGEventType.otherMouseDragged.rawValue)
        eventMask |= (1 << CGEventType.mouseMoved.rawValue)
        eventMask |= (1 << CGEventType.scrollWheel.rawValue)
        eventMask |= (1 << 14) // NX_SYSDEFINED: media keys, volume, brightness

        // Store self in an unmanaged pointer for the C callback
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            print("[EventTapManager] Failed to create event tap. Check Accessibility permission.")
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("[EventTapManager] Event tap started successfully")
        return true
    }

    /// Stop intercepting events and clean up.
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
        print("[EventTapManager] Event tap stopped")
    }

    /// Re-enable the tap if macOS disabled it (timeout or user input).
    func reEnable() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            print("[EventTapManager] Event tap re-enabled")
        }
    }

    /// Check if the tap is still enabled.
    var isTapEnabled: Bool {
        guard let tap = eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }
}

// MARK: - C callback (must be a free function)

/// The event tap callback. Called on the tap's thread for every intercepted event.
/// Contract: do minimal work, return immediately. No heap allocation except DispatchQueue.main.async.
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    // Handle tap disabled by timeout — re-enable immediately
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon = refcon {
            let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
            manager.reEnable()
        }
        return Unmanaged.passUnretained(event)
    }

    guard let refcon = refcon else {
        return nil // swallow if we can't get manager (shouldn't happen)
    }

    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()

    // For key events, check exit shortcut
    if type == .keyDown || type == .flagsChanged {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = event.flags

        if type == .keyDown && manager.shortcutDetector.matches(eventKeyCode: keyCode, eventModifiers: modifiers) {
            manager.eventBus.signalExitShortcut()
            return nil // swallow the shortcut itself
        }
    }

    // Build InputEvent and enqueue
    let inputEvent = buildInputEvent(type: type, event: event)
    if let inputEvent = inputEvent {
        manager.eventBus.enqueue(inputEvent)
    }

    // Swallow all events — return nil to prevent them from reaching the system
    return nil
}

/// Converts a CGEvent into our lightweight InputEvent struct.
/// Kept separate for clarity but inlined by the compiler.
private func buildInputEvent(type: CGEventType, event: CGEvent) -> InputEvent? {
    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let position = event.location
    let modifiers = event.flags
    let timestamp = event.timestamp

    // Get mouse delta for cursor tracking
    let deltaX = event.getDoubleValueField(.mouseEventDeltaX)
    let deltaY = event.getDoubleValueField(.mouseEventDeltaY)
    let delta = CGPoint(x: deltaX, y: deltaY)

    // Try to get characters for key events (this does allocate a String,
    // but only for key events which are infrequent compared to mouse moves)
    var characters: String? = nil
    if type == .keyDown {
        if let uniChars = event.copy() {
            // Create a CGEvent-based keyboard event and read its Unicode string
            var unicodeString = [UniChar](repeating: 0, count: 4)
            var length: Int = 0
            uniChars.keyboardGetUnicodeString(
                maxStringLength: 4,
                actualStringLength: &length,
                unicodeString: &unicodeString
            )
            if length > 0 {
                characters = String(utf16CodeUnits: unicodeString, count: length)
            }
        }
    }

    let scrollDeltaY: Double
    if type == .scrollWheel {
        scrollDeltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
    } else {
        scrollDeltaY = 0
    }

    let eventType: InputEvent.EventType
    switch type {
    case .keyDown:           eventType = .keyDown
    case .keyUp:             eventType = .keyUp
    case .flagsChanged:      eventType = .flagsChanged
    case .mouseMoved:        eventType = .mouseMove
    case .leftMouseDown:     eventType = .mouseDown
    case .leftMouseUp:       eventType = .mouseUp
    case .leftMouseDragged:  eventType = .mouseDragged
    case .rightMouseDown:    eventType = .rightMouseDown
    case .rightMouseUp:      eventType = .rightMouseUp
    case .scrollWheel:       eventType = .scrollWheel
    default:
        if type.rawValue == 14 { // NX_SYSDEFINED
            eventType = .systemDefined
        } else {
            return nil // Unknown event type, skip
        }
    }

    return InputEvent(
        type: eventType,
        keyCode: keyCode,
        characters: characters,
        position: position,
        delta: delta,
        modifiers: modifiers,
        timestamp: timestamp,
        scrollDeltaY: scrollDeltaY
    )
}
