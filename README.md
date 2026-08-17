# PaperMon

PaperMon is a native macOS wallpaper profile manager for multi-monitor desks. It remembers a distinct image and scaling mode for every display, then applies the entire arrangement from the main window or menu bar.

## Current capabilities

- Discovers connected displays and preserves their relative arrangement.
- Creates named profiles containing one assignment per display.
- Matches profiles after displays are reordered, reconnected, or assigned new transient display IDs.
- Accepts images through a Finder drop or native file picker.
- Copies images into a managed library by default, with optional security-scoped references to originals.
- Supports Fill, Fit, Stretch, and Center presentation modes.
- Applies every matched wallpaper with best-effort rollback if an operation fails.
- Restores the active profile after launch, wake, or display reconfiguration.
- Switches profiles from a concise menu-bar menu.

PaperMon remembers display orientation for matching and layout. It intentionally does not change macOS display rotation.

## Run

The Codex Run action and the project-local script both build a signed development app bundle:

```sh
./script/build_and_run.sh
```

Useful modes:

```sh
./script/build_and_run.sh --verify
./script/build_and_run.sh --debug
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

The resulting bundle is written to `dist/PaperMon.app`. The repository also includes `PaperMon.xcodeproj` and `project.yml` for Xcode signing and release work.

## Test

```sh
swift test
```

Tests cover versioned persistence, profile state, display matching, successful profile application, and rollback after a partial application failure.

## Storage

Profile metadata is stored under the user’s Application Support directory. Managed images are copied into the adjacent `PaperMon/Images` directory. Referenced originals use security-scoped bookmarks so access can survive relaunches and restarts.

## Release limitations

- Real hardware verification is still required across identical monitor models, DisplayLink docks, Sidecar, sleep/wake, and cable or port changes.
- Per-Space wallpapers, animated wallpapers, display rotation, scheduling, and cloud sync are not part of this MVP.
- Release distribution still requires a Developer ID or Mac App Store signing identity and notarization.

