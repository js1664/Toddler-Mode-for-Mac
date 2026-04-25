import AppKit
import Foundation

/// Handles checking for updates via GitHub Releases API, downloading the new DMG,
/// and replacing the running app with the updated version.
final class UpdateManager {
    static let shared = UpdateManager()

    private let githubRepo = "js1664/Toddler-Mode-for-Mac"
    private let downloadURL = URL(string: "https://suss.dev/toddlermodemac/ToddlerMode.dmg")!

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Whether a download is in progress
    private var isDownloading = false

    // MARK: - Public

    /// Check for updates (always user-initiated, always shows result).
    func checkForUpdates() {
        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    self.showError("Could not check for updates.\n\(error.localizedDescription)")
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.showError("Could not parse update information.")
                    return
                }

                let latestVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let body = json["body"] as? String ?? ""

                if self.isNewer(latestVersion, than: self.currentVersion) {
                    self.showUpdateAvailable(version: latestVersion, releaseNotes: body)
                } else {
                    self.showUpToDate()
                }
            }
        }.resume()
    }

    // MARK: - Version Comparison

    /// Returns true if `a` is a newer semantic version than `b`.
    private func isNewer(_ a: String, than b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let count = max(aParts.count, bParts.count)
        for i in 0..<count {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false
    }

    // MARK: - UI

    private func showUpdateAvailable(version: String, releaseNotes: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "Toddler Mode v\(version) is available. You have v\(currentVersion).\n\n\(releaseNotes)"
        alert.addButton(withTitle: "Download & Install")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational

        if let icon = NSImage(named: "AppIcon") {
            alert.icon = icon
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            downloadAndInstall()
        }
    }

    private func showUpToDate() {
        let alert = NSAlert()
        alert.messageText = "You're Up to Date"
        alert.informativeText = "Toddler Mode v\(currentVersion) is the latest version."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Download & Install

    private func downloadAndInstall() {
        guard !isDownloading else { return }
        isDownloading = true

        // Show a simple progress window
        let progressWindow = createProgressWindow()
        progressWindow.makeKeyAndOrderFront(nil)

        let dmgPath = NSTemporaryDirectory() + "ToddlerMode-update.dmg"
        try? FileManager.default.removeItem(atPath: dmgPath)

        let task = URLSession.shared.downloadTask(with: downloadURL) { [weak self] tempURL, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isDownloading = false
                progressWindow.close()

                guard let tempURL = tempURL else {
                    self.showError("Download failed.\n\(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                do {
                    let dest = URL(fileURLWithPath: dmgPath)
                    try FileManager.default.moveItem(at: tempURL, to: dest)
                    self.installFromDMG(at: dmgPath)
                } catch {
                    self.showError("Could not save update.\n\(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }

    private func createProgressWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Updating Toddler Mode"
        window.center()
        window.isReleasedWhenClosed = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: "Downloading update…")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.alignment = .center

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.startAnimation(nil)

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(spinner)

        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: window.contentView!.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: window.contentView!.centerYAnchor),
        ])

        return window
    }

    private func installFromDMG(at dmgPath: String) {
        let appPath = Bundle.main.bundlePath
        let appName = "Toddler Mode"

        // Shell script that:
        // 1. Mounts the DMG
        // 2. Waits for the app to exit
        // 3. Copies the new .app over the old one (tries direct, then admin)
        // 4. Relaunches the app
        // 5. Cleans up
        let script = """
        #!/bin/bash
        DMG_PATH="\(dmgPath)"
        APP_PATH="\(appPath)"
        APP_NAME="\(appName)"

        # Mount DMG silently
        hdiutil attach "$DMG_PATH" -nobrowse -quiet 2>/dev/null

        # Find the mounted volume
        MOUNT_POINT="/Volumes/$APP_NAME"
        if [ ! -d "$MOUNT_POINT" ]; then
            MOUNT_POINT=$(hdiutil info | grep -o '/Volumes/Toddler.*' | head -1)
        fi

        SOURCE_APP="$MOUNT_POINT/$APP_NAME.app"

        if [ ! -d "$SOURCE_APP" ]; then
            osascript -e 'display dialog "Update failed: Could not find the app in the downloaded image." buttons {"OK"} default button "OK" with icon caution'
            hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
            rm -f "$DMG_PATH"
            exit 1
        fi

        # Wait for the app to exit (max 15 seconds)
        for i in $(seq 1 30); do
            if ! pgrep -x "$APP_NAME" > /dev/null 2>&1; then
                break
            fi
            sleep 0.5
        done

        # Try direct copy first
        if ditto "$SOURCE_APP" "$APP_PATH" 2>/dev/null; then
            open "$APP_PATH"
        else
            # Need admin privileges — show password dialog
            osascript -e "do shell script \\"ditto '${SOURCE_APP}' '${APP_PATH}'\\" with administrator privileges" 2>/dev/null
            if [ $? -eq 0 ]; then
                open "$APP_PATH"
            else
                # Fall back: open DMG in Finder for manual drag-install
                open "$MOUNT_POINT"
                osascript -e 'display dialog "Automatic update failed. Please drag Toddler Mode to your Applications folder." buttons {"OK"} default button "OK" with icon caution'
                rm -f "$0"
                exit 0
            fi
        fi

        # Clean up
        sleep 2
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
        rm -f "$DMG_PATH"
        rm -f "$0"
        """

        let scriptPath = NSTemporaryDirectory() + "toddlermode-update.sh"
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptPath
            )

            // Launch the updater script detached
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()

            // Quit the app so the script can replace it
            // (applicationShouldTerminate returns .terminateNow when not locked)
            NSApp.terminate(nil)
        } catch {
            showError("Could not start the update process.\n\(error.localizedDescription)")
        }
    }
}
