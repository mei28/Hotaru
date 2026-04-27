# Hotaru

[![CI](https://github.com/mei28/Hotaru/actions/workflows/ci.yml/badge.svg)](https://github.com/mei28/Hotaru/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/mei28/Hotaru)](https://github.com/mei28/Hotaru/releases/latest)
[![License](https://img.shields.io/github/license/mei28/Hotaru)](./LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-blue)

> A macOS menu bar app that draws a soft colored border around the active window.

Since macOS Tahoe (Liquid Glass), telling the active window apart from inactive ones has become harder. Hotaru solves this by lighting a firefly-like border around whichever window has focus, following it as it moves and resizes.

## Features

- Colored border around the active window, updated live on move/resize
- Separate colors for Light and Dark mode (follows the system setting)
- Border width 1–10 px, editable from the settings window
- Menu bar icon with enable/disable toggle
- Launch at login (via `SMAppService`)
- English / 日本語 UI with in-app switcher
- Hidden in Mission Control, Exposé, and fullscreen apps

## Installation

Hotaru is distributed as an **unsigned** `.app` bundle. Pick whichever method you prefer.

### Homebrew (Cask)

The repository doubles as a [custom-URL Homebrew tap](https://docs.brew.sh/Taps#custom-url-taps), so no separate tap repo is needed.

```bash
brew tap mei28/hotaru https://github.com/mei28/Hotaru.git
brew install --cask hotaru
```

Homebrew handles the quarantine attribute, so the Gatekeeper dance is skipped. On first launch, Hotaru still asks for the Accessibility permission — enable it in **System Settings → Privacy & Security → Accessibility** and relaunch.

To upgrade after a new release: `brew update && brew upgrade --cask hotaru`. To remove: `brew uninstall --cask hotaru` (use `--zap` to also delete preferences).

### Nix flake

The flake fetches the same release zip and unpacks the `.app` into the Nix store. Apple Silicon (`aarch64-darwin`) only.

```bash
nix profile install github:mei28/Hotaru
# or, ad-hoc:
nix run github:mei28/Hotaru
```

The installed `.app` lives under `~/.nix-profile/Applications/Hotaru.app`. To make it visible to Spotlight/Launchpad, link it into `/Applications` or your home `~/Applications`:

```bash
ln -sfn "$HOME/.nix-profile/Applications/Hotaru.app" "$HOME/Applications/Hotaru.app"
```

### Manual download

1. Download `Hotaru-<version>.zip` from the [latest release](https://github.com/mei28/Hotaru/releases/latest).
2. Unzip and move `Hotaru.app` to `/Applications`.
3. **First launch only**: right-click `Hotaru.app` → **Open** → **Open** in the Gatekeeper dialog. Double-clicking will not work the first time.
4. Hotaru requests the Accessibility permission. Click **Open System Settings**, enable Hotaru in **System Settings → Privacy & Security → Accessibility**, and quit-and-relaunch Hotaru.

If the quarantine attribute bothers you, you can remove it manually:

```bash
xattr -dr com.apple.quarantine /Applications/Hotaru.app
```

## Requirements

- macOS 26 Tahoe or later (tested on 26.3)
- Apple Silicon (arm64). Intel is not distributed; build from source if you need it.

## Usage

- The menu bar icon (sparkles) opens a small menu with **Enable/Disable**, **Settings…**, **About Hotaru**, and **Quit Hotaru**.
- `⌘,` from the menu opens settings, where you can pick colors, width, language, and whether to launch at login.
- The border hides automatically in fullscreen apps, Mission Control, and Exposé.
- Switching the in-app language takes effect immediately for the settings window; click **Relaunch Hotaru** to update the menu bar and system dialogs.

## Build from source

Requirements: macOS 13+, Xcode 16+, Homebrew.

```bash
brew install just xcode-build-server xcbeautify
git clone https://github.com/mei28/Hotaru.git
cd Hotaru
just doctor   # sanity-check the toolchain
just build    # debug build
just run      # debug build + launch
just release  # release build + zip into ./dist/
```

Run `just --list` for all recipes (build, run, run-fg, run-ja, run-en, log, lsp, release, version, clean).

### Install locally from source

If you just want to run Hotaru on your own Mac without going through a GitHub release:

```bash
just install    # Release build -> /Applications/Hotaru.app (ad-hoc signed)
```

The recipe stops any running instance, replaces `/Applications/Hotaru.app` with the fresh build, and strips the quarantine attribute. Because the binary path changes, macOS treats the installed copy as a different app — grant Accessibility permission again for `/Applications/Hotaru.app` on first launch. `just uninstall` removes it.

### Editing in nvim

The project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), so any `.swift` file placed under `Hotaru/Hotaru/` is automatically added to the target — no Xcode GUI steps required.

Generate `buildServer.json` so that sourcekit-lsp (via `xcode-build-server`) can resolve the project:

```bash
just lsp
```

## Architecture

```
Hotaru/Hotaru/
├── HotaruApp.swift            # @main, SwiftUI Settings scene wiring
├── AppDelegate.swift          # NSApplicationDelegate; composes the runtime
├── Core/
│   ├── AccessibilityChecker.swift   # AX permission gate
│   ├── FocusTracker.swift           # NSWorkspace front-app observer
│   ├── AXWindowQuery.swift          # AXUIElementCopyAttributeValue wrappers
│   ├── WindowInfo.swift             # Value type for (position, size)
│   ├── ScreenGeometry.swift         # AX ⇄ Cocoa coordinate conversion
│   └── WindowObserver.swift         # AXObserver for move/resize/focus
├── Overlay/
│   ├── OverlayWindow.swift          # Transparent borderless NSWindow
│   ├── OverlayView.swift            # CALayer-backed border rendering
│   └── OverlayController.swift      # Orchestrates style + repositioning
├── Settings/
│   ├── Preferences.swift            # UserDefaults wrapper, ObservableObject
│   ├── SettingsView.swift           # SwiftUI settings UI
│   ├── SettingsWindowController.swift # NSWindowController + NSHostingController
│   ├── AppLanguage.swift            # Language enum for in-app switching
│   └── Localizable.xcstrings        # en + ja strings catalog
└── MenuBar/
    └── MenuBarController.swift      # NSStatusItem + menu
```

## Releasing

Tag push triggers a GitHub Actions job that produces a zipped Release build and attaches it to the GitHub Release.

```bash
just version 1.0.1   # bump MARKETING_VERSION in pbxproj
git commit -am "chore: bump to 1.0.1"
git tag v1.0.1
git push origin main --tags
```

## License

MIT — see [LICENSE](./LICENSE).
