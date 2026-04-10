# Toddler Mode

A macOS app that lets your toddlers safely mash the keyboard and mouse without doing anything to your computer.

When locked, Toddler Mode takes over the entire screen and blocks all keyboard shortcuts, trackpad gestures, and system controls. Your kids see fun colorful animations, hear musical sounds, and feel like they're doing something — while your Mac stays completely safe.

## Features

- **Full input blocking** — Command-Tab, Mission Control, volume/brightness keys, and trackpad gestures are all disabled
- **Three play modes:**
  - **Free Play** — Mash keys to see colorful letters, click for shapes and particle effects, move the mouse for a rainbow cursor trail
  - **Game** — Pop floating bubbles by clicking them, with a score counter
  - **Character** — A friendly animated creature follows the mouse, jumps and spins on key presses, and leaves rainbow paw prints
- **Multi-language letters** — Choose from Arabic, Chinese, English, Hebrew, Japanese, or Korean character sets
- **Musical sounds** — Each key plays a pentatonic tone (always sounds pleasant), with optional background music
- **Customizable exit shortcut** — Set any key combination (requires 2+ modifiers) to exit lock mode
- **Optional password protection** — Require a password to unlock (stored securely in macOS Keychain)
- **Debug safety** — Development builds auto-unlock after 60 seconds so you never get trapped

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## Installation

### Download

Download the latest release from the [Releases page](https://github.com/js1664/toddlerlock/releases).

1. Download **Toddler Mode.dmg**
2. Open the DMG and drag **Toddler Mode.app** to your Applications folder
3. Open Toddler Mode from Applications
4. Grant **Accessibility** and **Input Monitoring** permissions when prompted (System Settings > Privacy & Security)

### Build from Source

1. Clone this repo
2. Open `ToddlerLock/ToddlerLock.xcodeproj` in Xcode 16+
3. Set your Development Team in Signing & Capabilities
4. Build and run (Cmd+R)

## How It Works

1. **Open Toddler Mode** — configure your play mode, exit shortcut, and optional password
2. **Click "Lock Now"** — the screen goes full-screen with animations
3. **Hand it to your toddler** — they mash keys and move the mouse, everything stays safe
4. **Press your exit shortcut** (default: Cmd+Shift+Esc) — enter your password if set, and you're back to normal

## How to Exit

- Press your configured shortcut (default: **Cmd+Shift+Esc**)
- Or restart the computer

## Permissions

Toddler Mode needs two macOS permissions to block input:

- **Accessibility** — allows the app to manage system presentation options
- **Input Monitoring** — allows the app to intercept keyboard and mouse events

These are granted in System Settings > Privacy & Security. The app will guide you through this on first launch.

## Technical Details

Built with Swift, AppKit, and SpriteKit. Input blocking uses `CGEventTap` (intercepts events at the system level) and `NSApplication.PresentationOptions` (hides Dock, menu bar, and disables process switching). Sound is synthesized in real-time via `AVAudioEngine`.

## License

MIT
