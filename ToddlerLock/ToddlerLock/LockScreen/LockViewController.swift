import AppKit
import SpriteKit

/// Hosts the SpriteKit view and consumes events from the InputEventBus.
/// Routes events to the active play mode.
final class LockViewController: NSViewController {
    private var skView: SKView!
    private var activeMode: PlayMode?
    private let cursorManager = CursorManager.shared
    private let eventBus = InputEventBus.shared

    var currentMode: PlayModeType = .freePlay

    override func loadView() {
        skView = SKView()
        skView.ignoresSiblingOrder = true
        skView.allowsTransparency = false

        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #endif

        self.view = skView
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        setupMode()
        setupEventRouting()
    }

    private func setupMode() {
        guard let window = view.window else { return }
        let size = window.frame.size

        switch currentMode {
        case .freePlay:
            let mode = FreePlayMode(size: size)
            activeMode = mode
            skView.presentScene(mode.scene)
        case .game:
            // Placeholder: use FreePlayMode for now, GameMode built in Phase 5
            let mode = FreePlayMode(size: size)
            activeMode = mode
            skView.presentScene(mode.scene)
        case .character:
            // Placeholder: use FreePlayMode for now, CharacterMode built in Phase 5
            let mode = FreePlayMode(size: size)
            activeMode = mode
            skView.presentScene(mode.scene)
        }
    }

    private func setupEventRouting() {
        eventBus.onAnimationEvent = { [weak self] event in
            guard let self = self, let mode = self.activeMode else { return }

            switch event.type {
            case .keyDown:
                mode.handleKeyDown(keyCode: event.keyCode, characters: event.characters)

            case .keyUp:
                mode.handleKeyUp(keyCode: event.keyCode)

            case .mouseMove, .mouseDragged:
                // Use delta to update virtual cursor position
                let pos = self.cursorManager.updatePosition(delta: event.delta)
                // Convert screen coords to scene coords (flip Y since SpriteKit Y is up)
                if let window = self.view.window {
                    let scenePos = CGPoint(x: pos.x, y: window.frame.height - pos.y)
                    mode.handleMouseMove(position: scenePos)
                }

            case .mouseDown:
                let pos = self.cursorManager.virtualPosition
                if let window = self.view.window {
                    let scenePos = CGPoint(x: pos.x, y: window.frame.height - pos.y)
                    mode.handleMouseDown(position: scenePos)
                }

            default:
                break
            }
        }
    }

}
