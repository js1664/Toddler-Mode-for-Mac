import SpriteKit
import AppKit

/// Game Mode: colorful bubbles spawn and float around.
/// Click them to pop with satisfying animations and sounds.
/// Score counter tracks pops.
final class GameMode: PlayMode {
    let scene: SKScene
    private let soundManager = SoundManager.shared
    private var score = 0
    private var scoreLabel: SKLabelNode!
    private var spawnTimer: Timer?
    private var cursorFollower: SKShapeNode?

    private let colors: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemBlue, .systemPurple, .systemPink, .systemTeal,
    ]

    init(size: CGSize) {
        let s = SKScene(size: size)
        s.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0)
        s.scaleMode = .resizeFill
        s.physicsWorld.gravity = CGVector(dx: 0, dy: 0.3) // Gentle upward float
        self.scene = s

        setupScoreLabel()
        setupCursorFollower()
        startSpawning()

        // Spawn initial batch
        for _ in 0..<8 {
            spawnBubble()
        }
    }

    deinit {
        spawnTimer?.invalidate()
    }

    // MARK: - PlayMode

    func handleKeyDown(keyCode: UInt16, characters: String?) {
        // In game mode, keys spawn extra bubbles
        spawnBubble()
        soundManager.playKeyTone(keyCode: keyCode)
    }

    func handleKeyUp(keyCode: UInt16) {}

    func handleMouseMove(position: CGPoint) {
        cursorFollower?.position = position
    }

    func handleMouseDown(position: CGPoint) {
        // Check if we hit a bubble
        let nodes = scene.nodes(at: position)
        var popped = false

        for node in nodes {
            if node.name == "bubble" {
                popBubble(node)
                popped = true
                break
            }
            // Check parent (for bubbles with child labels)
            if let parent = node.parent, parent.name == "bubble" {
                popBubble(parent)
                popped = true
                break
            }
        }

        if !popped {
            // Clicked empty space — spawn a small burst
            spawnClickBurst(at: position)
        }
    }

    func handleMouseDragged(position: CGPoint) {
        handleMouseMove(position: position)
        // Check for drag-popping bubbles
        let nodes = scene.nodes(at: position)
        for node in nodes {
            if node.name == "bubble" {
                popBubble(node)
                break
            }
        }
    }

    // MARK: - Bubbles

    private func spawnBubble() {
        let radius = CGFloat.random(in: 25...60)
        let color = colors.randomElement()!

        let bubble = SKShapeNode(circleOfRadius: radius)
        bubble.fillColor = color.withAlphaComponent(0.7)
        bubble.strokeColor = color.withAlphaComponent(0.9)
        bubble.lineWidth = 2
        bubble.name = "bubble"
        bubble.zPosition = 10

        // Random position
        let x = CGFloat.random(in: radius...(scene.size.width - radius))
        let y = CGFloat.random(in: radius...(scene.size.height * 0.6))
        bubble.position = CGPoint(x: x, y: y)

        // Shine highlight
        let shine = SKShapeNode(circleOfRadius: radius * 0.3)
        shine.fillColor = .white
        shine.strokeColor = .clear
        shine.alpha = 0.3
        shine.position = CGPoint(x: -radius * 0.2, y: radius * 0.25)
        bubble.addChild(shine)

        // Physics for gentle floating
        bubble.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        bubble.physicsBody?.isDynamic = true
        bubble.physicsBody?.linearDamping = 2.0
        bubble.physicsBody?.restitution = 0.8
        bubble.physicsBody?.categoryBitMask = 0x1
        bubble.physicsBody?.collisionBitMask = 0x1
        bubble.physicsBody?.mass = 0.1

        // Gentle wobble
        let wobble = SKAction.sequence([
            SKAction.moveBy(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: -15...15), duration: Double.random(in: 1.5...3.0)),
            SKAction.moveBy(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: -15...15), duration: Double.random(in: 1.5...3.0)),
        ])
        bubble.run(SKAction.repeatForever(wobble))

        // Scale in
        bubble.setScale(0)
        bubble.run(SKAction.scale(to: 1.0, duration: 0.3))

        scene.addChild(bubble)
    }

    private func popBubble(_ node: SKNode) {
        guard node.name == "bubble" else { return }
        node.name = "popping" // Prevent double-pop

        score += 1
        updateScore()
        soundManager.playPop()

        let pos = node.position

        // Pop animation
        let scaleUp = SKAction.scale(to: 1.4, duration: 0.08)
        let fadeOut = SKAction.fadeOut(withDuration: 0.1)
        let pop = SKAction.group([scaleUp, fadeOut])
        let remove = SKAction.removeFromParent()

        node.run(SKAction.sequence([pop, remove]))

        // Particle burst
        spawnPopParticles(at: pos, color: (node as? SKShapeNode)?.fillColor ?? .white)

        // Score popup
        let popup = SKLabelNode(text: "+1")
        popup.fontName = "AvenirNext-Bold"
        popup.fontSize = 32
        popup.fontColor = .systemYellow
        popup.position = pos
        popup.zPosition = 50
        scene.addChild(popup)

        let rise = SKAction.moveBy(x: 0, y: 60, duration: 0.6)
        let fade = SKAction.fadeOut(withDuration: 0.6)
        popup.run(SKAction.sequence([SKAction.group([rise, fade]), SKAction.removeFromParent()]))

        // Spawn replacement after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.spawnBubble()
        }
    }

    private func spawnPopParticles(at position: CGPoint, color: NSColor) {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 100
        emitter.numParticlesToEmit = 20
        emitter.particleLifetime = 0.5
        emitter.particleSpeed = 200
        emitter.particleSpeedRange = 100
        emitter.emissionAngleRange = .pi * 2
        emitter.particleScale = 0.4
        emitter.particleScaleSpeed = -0.5
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -2.0
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.position = position
        emitter.zPosition = 30

        let size = CGSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        emitter.particleTexture = SKTexture(image: image)

        scene.addChild(emitter)
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.removeFromParent(),
        ]))
    }

    private func spawnClickBurst(at position: CGPoint) {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 50
        emitter.numParticlesToEmit = 10
        emitter.particleLifetime = 0.3
        emitter.particleSpeed = 80
        emitter.emissionAngleRange = .pi * 2
        emitter.particleScale = 0.2
        emitter.particleAlphaSpeed = -3.0
        emitter.particleColor = .white
        emitter.particleColorBlendFactor = 1.0
        emitter.position = position
        emitter.zPosition = 30

        let size = CGSize(width: 8, height: 8)
        let image = NSImage(size: size, flipped: false) { rect in
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        emitter.particleTexture = SKTexture(image: image)

        scene.addChild(emitter)
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.removeFromParent(),
        ]))
    }

    // MARK: - UI

    private func setupScoreLabel() {
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.fontName = "AvenirNext-Bold"
        scoreLabel.fontSize = 36
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height - 60)
        scoreLabel.zPosition = 100
        scene.addChild(scoreLabel)
    }

    private func updateScore() {
        scoreLabel.text = "Score: \(score)"
        // Bounce animation on score change
        scoreLabel.run(SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1),
        ]))
    }

    private func setupCursorFollower() {
        let follower = SKShapeNode(circleOfRadius: 15)
        follower.fillColor = .white
        follower.strokeColor = .systemYellow
        follower.lineWidth = 2
        follower.alpha = 0.8
        follower.zPosition = 100
        follower.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)

        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.4),
            SKAction.scale(to: 1.0, duration: 0.4),
        ]))
        follower.run(pulse)

        cursorFollower = follower
        scene.addChild(follower)
    }

    private func startSpawning() {
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.spawnBubble()
        }
    }
}
