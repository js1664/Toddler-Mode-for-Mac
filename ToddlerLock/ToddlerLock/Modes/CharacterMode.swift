import SpriteKit
import AppKit

/// Character Mode: a friendly animated character follows the mouse cursor
/// with smooth interpolation. Keys trigger fun actions (jump, spin, wave).
/// Leaves a trail of colorful paw prints.
final class CharacterMode: PlayMode {
    let scene: SKScene
    private let soundManager = SoundManager.shared
    private let characterSet: LetterCharacterSet

    private var character: SKNode!
    private var body: SKShapeNode!
    private var leftEye: SKShapeNode!
    private var rightEye: SKShapeNode!
    private var mouth: SKShapeNode!
    private var targetPosition: CGPoint = .zero
    private var lastPawPrintPos: CGPoint = .zero

    private let colors: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemBlue, .systemPurple, .systemPink,
    ]

    private let pawColors: [NSColor] = [
        .systemPink, .systemPurple, .systemBlue, .systemCyan,
        .systemGreen, .systemYellow, .systemOrange,
    ]

    private var pawColorIndex = 0

    init(size: CGSize, characterSet: LetterCharacterSet = .english) {
        self.characterSet = characterSet
        let s = SKScene(size: size)
        s.backgroundColor = NSColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1.0) // Grassy green
        s.scaleMode = .resizeFill
        self.scene = s

        targetPosition = CGPoint(x: size.width / 2, y: size.height / 2)
        setupBackground()
        setupCharacter()

        // Update loop for smooth movement
        let updateAction = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 1.0 / 60.0),
            SKAction.run { [weak self] in self?.updateCharacter() },
        ]))
        s.run(updateAction)
    }

    // MARK: - PlayMode

    func handleKeyDown(keyCode: UInt16, characters: String?) {
        soundManager.playKeyTone(keyCode: keyCode)

        // Different actions based on key groups
        let action = Int(keyCode) % 4
        switch action {
        case 0: doJump()
        case 1: doSpin()
        case 2: doSquash()
        case 3: doColorChange()
        default: break
        }

        // Spawn a letter from the selected character set above the character
        spawnSpeechBubble(characterSet.character(for: keyCode))
    }

    func handleKeyUp(keyCode: UInt16) {}

    func handleMouseMove(position: CGPoint) {
        targetPosition = position
    }

    func handleMouseDown(position: CGPoint) {
        targetPosition = position
        doJump()
        soundManager.playPop()
        spawnStarBurst(at: position)
    }

    func handleMouseDragged(position: CGPoint) {
        targetPosition = position
    }

    // MARK: - Character Setup

    private func setupCharacter() {
        character = SKNode()
        character.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        character.zPosition = 50

        // Body - round friendly shape
        body = SKShapeNode(circleOfRadius: 40)
        body.fillColor = .systemOrange
        body.strokeColor = .white
        body.lineWidth = 3
        character.addChild(body)

        // Left ear
        let leftEar = SKShapeNode(ellipseOf: CGSize(width: 20, height: 30))
        leftEar.fillColor = .systemOrange
        leftEar.strokeColor = .white
        leftEar.lineWidth = 2
        leftEar.position = CGPoint(x: -25, y: 35)
        leftEar.zRotation = 0.3
        character.addChild(leftEar)

        // Right ear
        let rightEar = SKShapeNode(ellipseOf: CGSize(width: 20, height: 30))
        rightEar.fillColor = .systemOrange
        rightEar.strokeColor = .white
        rightEar.lineWidth = 2
        rightEar.position = CGPoint(x: 25, y: 35)
        rightEar.zRotation = -0.3
        character.addChild(rightEar)

        // Eyes
        leftEye = SKShapeNode(circleOfRadius: 8)
        leftEye.fillColor = .white
        leftEye.strokeColor = .clear
        leftEye.position = CGPoint(x: -14, y: 8)
        character.addChild(leftEye)

        let leftPupil = SKShapeNode(circleOfRadius: 4)
        leftPupil.fillColor = .black
        leftPupil.strokeColor = .clear
        leftPupil.name = "leftPupil"
        leftEye.addChild(leftPupil)

        rightEye = SKShapeNode(circleOfRadius: 8)
        rightEye.fillColor = .white
        rightEye.strokeColor = .clear
        rightEye.position = CGPoint(x: 14, y: 8)
        character.addChild(rightEye)

        let rightPupil = SKShapeNode(circleOfRadius: 4)
        rightPupil.fillColor = .black
        rightPupil.strokeColor = .clear
        rightPupil.name = "rightPupil"
        rightEye.addChild(rightPupil)

        // Mouth - happy smile
        let mouthPath = CGMutablePath()
        mouthPath.addArc(center: .zero, radius: 12, startAngle: -.pi * 0.2, endAngle: -.pi * 0.8, clockwise: true)
        mouth = SKShapeNode(path: mouthPath)
        mouth.strokeColor = .black
        mouth.lineWidth = 3
        mouth.fillColor = .clear
        mouth.position = CGPoint(x: 0, y: -8)
        character.addChild(mouth)

        // Nose
        let nose = SKShapeNode(circleOfRadius: 5)
        nose.fillColor = .brown
        nose.strokeColor = .clear
        nose.position = CGPoint(x: 0, y: 0)
        character.addChild(nose)

        scene.addChild(character)
        lastPawPrintPos = character.position
    }

    private func setupBackground() {
        // Sky gradient at top
        let sky = SKSpriteNode(color: NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0),
                               size: CGSize(width: scene.size.width, height: scene.size.height * 0.4))
        sky.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.8)
        sky.zPosition = -10
        scene.addChild(sky)

        // Clouds
        for _ in 0..<5 {
            let cloud = createCloud()
            cloud.position = CGPoint(
                x: CGFloat.random(in: 0...scene.size.width),
                y: CGFloat.random(in: scene.size.height * 0.65...scene.size.height * 0.95)
            )
            cloud.zPosition = -5

            // Drift animation
            let drift = SKAction.moveBy(x: CGFloat.random(in: 30...80), y: 0, duration: Double.random(in: 8...15))
            let driftBack = drift.reversed()
            cloud.run(SKAction.repeatForever(SKAction.sequence([drift, driftBack])))

            scene.addChild(cloud)
        }

        // Flowers scattered on ground
        for _ in 0..<15 {
            let flower = createFlower()
            flower.position = CGPoint(
                x: CGFloat.random(in: 20...scene.size.width - 20),
                y: CGFloat.random(in: 20...scene.size.height * 0.35)
            )
            flower.zPosition = 0
            scene.addChild(flower)
        }
    }

    private func createCloud() -> SKNode {
        let cloud = SKNode()
        let offsets: [(CGFloat, CGFloat, CGFloat)] = [
            (0, 0, 25), (-20, 5, 20), (20, 5, 20), (-10, 12, 18), (10, 12, 18),
        ]
        for (x, y, r) in offsets {
            let puff = SKShapeNode(circleOfRadius: r)
            puff.fillColor = .white
            puff.strokeColor = .clear
            puff.alpha = 0.9
            puff.position = CGPoint(x: x, y: y)
            cloud.addChild(puff)
        }
        return cloud
    }

    private func createFlower() -> SKNode {
        let flower = SKNode()
        let petalColor = colors.randomElement()!

        // Petals
        for i in 0..<5 {
            let petal = SKShapeNode(ellipseOf: CGSize(width: 8, height: 12))
            petal.fillColor = petalColor
            petal.strokeColor = .clear
            let angle = CGFloat(i) * (.pi * 2 / 5)
            petal.position = CGPoint(x: cos(angle) * 6, y: sin(angle) * 6)
            petal.zRotation = angle
            flower.addChild(petal)
        }

        // Center
        let center = SKShapeNode(circleOfRadius: 4)
        center.fillColor = .systemYellow
        center.strokeColor = .clear
        flower.addChild(center)

        return flower
    }

    // MARK: - Character Movement

    private func updateCharacter() {
        guard let character = character else { return }

        // Smooth interpolation toward target
        let dx = targetPosition.x - character.position.x
        let dy = targetPosition.y - character.position.y
        let lerp: CGFloat = 0.08

        character.position.x += dx * lerp
        character.position.y += dy * lerp

        // Lean in movement direction
        let lean = max(-0.3, min(0.3, dx * 0.003))
        character.zRotation = lean

        // Move pupils toward target
        let pupilOffset = CGPoint(
            x: max(-3, min(3, dx * 0.01)),
            y: max(-3, min(3, dy * 0.01))
        )
        leftEye.childNode(withName: "leftPupil")?.position = pupilOffset
        rightEye.childNode(withName: "rightPupil")?.position = pupilOffset

        // Leave paw prints
        let dist = hypot(character.position.x - lastPawPrintPos.x, character.position.y - lastPawPrintPos.y)
        if dist > 50 {
            spawnPawPrint(at: character.position)
            lastPawPrintPos = character.position
        }
    }

    // MARK: - Actions

    private func doJump() {
        let jump = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 60, duration: 0.2),
            SKAction.moveBy(x: 0, y: -60, duration: 0.2),
        ])
        jump.timingMode = .easeInEaseOut
        character.run(jump)
    }

    private func doSpin() {
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: 0.4)
        spin.timingMode = .easeInEaseOut
        character.run(spin)
    }

    private func doSquash() {
        let squash = SKAction.sequence([
            SKAction.scaleX(to: 1.3, y: 0.7, duration: 0.1),
            SKAction.scaleX(to: 0.8, y: 1.2, duration: 0.1),
            SKAction.scaleX(to: 1.0, y: 1.0, duration: 0.1),
        ])
        character.run(squash)
    }

    private func doColorChange() {
        let newColor = colors.randomElement()!
        body.fillColor = newColor

        // Flash effect
        let flash = SKAction.sequence([
            SKAction.run { self.body.strokeColor = .systemYellow },
            SKAction.wait(forDuration: 0.2),
            SKAction.run { self.body.strokeColor = .white },
        ])
        character.run(flash)
    }

    // MARK: - Effects

    private func spawnPawPrint(at position: CGPoint) {
        let pawColor = pawColors[pawColorIndex % pawColors.count]
        pawColorIndex += 1

        let paw = SKNode()
        paw.position = position
        paw.zPosition = 5

        // Main pad
        let pad = SKShapeNode(ellipseOf: CGSize(width: 12, height: 10))
        pad.fillColor = pawColor
        pad.strokeColor = .clear
        pad.alpha = 0.6
        paw.addChild(pad)

        // Toe pads
        let toePositions: [CGPoint] = [
            CGPoint(x: -6, y: 7), CGPoint(x: 0, y: 9), CGPoint(x: 6, y: 7),
        ]
        for pos in toePositions {
            let toe = SKShapeNode(circleOfRadius: 3)
            toe.fillColor = pawColor
            toe.strokeColor = .clear
            toe.alpha = 0.6
            toe.position = pos
            paw.addChild(toe)
        }

        scene.addChild(paw)

        // Fade out after a few seconds
        paw.run(SKAction.sequence([
            SKAction.wait(forDuration: 3.0),
            SKAction.fadeOut(withDuration: 1.0),
            SKAction.removeFromParent(),
        ]))
    }

    private func spawnSpeechBubble(_ text: String) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 40
        label.fontColor = colors.randomElement()!
        label.position = CGPoint(
            x: character.position.x + CGFloat.random(in: -30...30),
            y: character.position.y + 60
        )
        label.zPosition = 80
        label.setScale(0)
        scene.addChild(label)

        let appear = SKAction.scale(to: 1.0, duration: 0.15)
        let wait = SKAction.wait(forDuration: 0.8)
        let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.8)
        let fade = SKAction.fadeOut(withDuration: 0.8)
        let exit = SKAction.group([rise, fade])

        label.run(SKAction.sequence([appear, wait, exit, SKAction.removeFromParent()]))
    }

    private func spawnStarBurst(at position: CGPoint) {
        for _ in 0..<5 {
            let star = SKShapeNode(path: starPath(points: 5, outerRadius: 12, innerRadius: 5))
            star.fillColor = colors.randomElement()!
            star.strokeColor = .clear
            star.position = position
            star.zPosition = 60

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist = CGFloat.random(in: 40...100)
            let dx = cos(angle) * dist
            let dy = sin(angle) * dist

            scene.addChild(star)
            star.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.5),
                    SKAction.rotate(byAngle: .pi * 2, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
    }

    private func starPath(points: Int, outerRadius: CGFloat, innerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let angleIncrement = .pi * 2 / CGFloat(points)
        for i in 0..<points {
            let outerAngle = CGFloat(i) * angleIncrement - .pi / 2
            let innerAngle = outerAngle + angleIncrement / 2
            let outerPoint = CGPoint(x: cos(outerAngle) * outerRadius, y: sin(outerAngle) * outerRadius)
            let innerPoint = CGPoint(x: cos(innerAngle) * innerRadius, y: sin(innerAngle) * innerRadius)
            if i == 0 { path.move(to: outerPoint) } else { path.addLine(to: outerPoint) }
            path.addLine(to: innerPoint)
        }
        path.closeSubpath()
        return path
    }
}
