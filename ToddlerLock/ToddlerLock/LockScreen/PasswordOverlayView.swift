import AppKit

/// Password overlay that appears when the exit shortcut is triggered.
/// Receives key events from InputEventBus in .password routing mode —
/// the event tap stays active the entire time.
final class PasswordOverlayView: NSView {
    private var passwordField: NSSecureTextField!
    private var titleLabel: NSTextField!
    private var messageLabel: NSTextField!
    private var unlockButton: NSButton!
    private var cancelButton: NSButton!
    private var containerView: NSView!

    /// Called when the correct password is entered.
    var onUnlock: (() -> Void)?

    /// Called when the user cancels (or timeout).
    var onCancel: (() -> Void)?

    /// Password is verified via KeychainManager

    /// Buffer for password characters received from InputEventBus
    private var passwordBuffer: String = ""

    /// Timeout timer
    private var timeoutTimer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor

        // Container
        containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.darkGray.withAlphaComponent(0.9).cgColor
        containerView.layer?.cornerRadius = 16
        addSubview(containerView)

        // Title
        titleLabel = NSTextField(labelWithString: "Toddler Mode")
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        containerView.addSubview(titleLabel)

        // Message
        messageLabel = NSTextField(labelWithString: "Enter password to unlock")
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textColor = .lightGray
        messageLabel.alignment = .center
        containerView.addSubview(messageLabel)

        // Password dots display (we show dots since we handle input manually)
        passwordField = NSSecureTextField()
        passwordField.font = .systemFont(ofSize: 20)
        passwordField.alignment = .center
        passwordField.placeholderString = "Password"
        passwordField.isBezeled = true
        passwordField.bezelStyle = .roundedBezel
        passwordField.isEditable = false  // We handle input via InputEventBus
        containerView.addSubview(passwordField)

        // Unlock button
        unlockButton = NSButton(title: "Unlock", target: self, action: #selector(unlockTapped))
        unlockButton.bezelStyle = .rounded
        unlockButton.font = .systemFont(ofSize: 16, weight: .semibold)
        containerView.addSubview(unlockButton)

        // Cancel button
        cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.font = .systemFont(ofSize: 14)
        containerView.addSubview(cancelButton)
    }

    override func layout() {
        super.layout()

        let containerWidth: CGFloat = 400
        let containerHeight: CGFloat = 260
        containerView.frame = CGRect(
            x: (bounds.width - containerWidth) / 2,
            y: (bounds.height - containerHeight) / 2,
            width: containerWidth,
            height: containerHeight
        )

        let padding: CGFloat = 30
        var y = containerHeight - padding

        titleLabel.frame = CGRect(x: padding, y: y - 34, width: containerWidth - padding * 2, height: 34)
        y -= 50

        messageLabel.frame = CGRect(x: padding, y: y - 22, width: containerWidth - padding * 2, height: 22)
        y -= 40

        passwordField.frame = CGRect(x: padding, y: y - 30, width: containerWidth - padding * 2, height: 30)
        y -= 50

        let buttonWidth: CGFloat = 120
        unlockButton.frame = CGRect(
            x: containerWidth / 2 + 10,
            y: y - 30,
            width: buttonWidth,
            height: 30
        )
        cancelButton.frame = CGRect(
            x: containerWidth / 2 - buttonWidth - 10,
            y: y - 30,
            width: buttonWidth,
            height: 30
        )
    }

    /// Show the overlay and start accepting password input.
    func show() {
        isHidden = false
        passwordBuffer = ""
        updatePasswordDisplay()
        startTimeout()
    }

    /// Hide the overlay.
    func hide() {
        isHidden = true
        passwordBuffer = ""
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    /// Handle a key event from the InputEventBus (in .password routing mode).
    func handleKeyEvent(_ event: InputEvent) {
        guard event.type == .keyDown else { return }

        // Return/Enter key: attempt unlock
        if event.keyCode == 36 || event.keyCode == 76 {
            attemptUnlock()
            return
        }

        // Escape key: cancel
        if event.keyCode == 53 {
            cancelTapped()
            return
        }

        // Delete/Backspace
        if event.keyCode == 51 {
            if !passwordBuffer.isEmpty {
                passwordBuffer.removeLast()
                updatePasswordDisplay()
            }
            return
        }

        // Regular character
        if let chars = event.characters, !chars.isEmpty {
            // Filter out control characters
            let filtered = chars.filter { !$0.isNewline && $0.asciiValue ?? 0 >= 32 }
            if !filtered.isEmpty {
                passwordBuffer.append(filtered)
                updatePasswordDisplay()
            }
        }
    }

    private func updatePasswordDisplay() {
        // Show dots for password length
        passwordField.stringValue = String(repeating: "\u{2022}", count: passwordBuffer.count)
    }

    private func attemptUnlock() {
        if KeychainManager.verifyPassword(passwordBuffer) {
            hide()
            onUnlock?()
        } else {
            // Shake animation
            shakeContainer()
            passwordBuffer = ""
            updatePasswordDisplay()
            messageLabel.stringValue = "Incorrect password. Try again."
            messageLabel.textColor = .systemRed
        }
    }

    @objc private func unlockTapped() {
        attemptUnlock()
    }

    @objc private func cancelTapped() {
        hide()
        onCancel?()
    }

    private func shakeContainer() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.4
        animation.values = [-10, 10, -8, 8, -5, 5, -2, 2, 0]
        containerView.layer?.add(animation, forKey: "shake")
    }

    private func startTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.cancelTapped()
        }
    }
}
