# Icon Composter

### ⬇️ [Download the app (Icon-Composter.zip)](https://github.com/dmtr-shvydkyi/icon-composter/releases/latest/download/Icon-Composter.zip)

> First launch: move it to `~/Applications`, then **right-click → Open** once.
> Requires macOS 26 (Tahoe) and Xcode. See [Sending it to teammates](#sending-it-to-teammates).

A tiny macOS Tahoe app for live-testing app icons made in **Icon Composer**.
Drop a `.icon` file and it becomes the app's **real** Dock icon — so it renders
with full system styling (light/dark **and** the Default / Dark / Clear / Tinted
"Icon & widget style"), exactly like a shipping app.

## Requirements

- **macOS 26 (Tahoe)** or later.
- **Xcode installed.** The app shells out to `actool` (to compile the `.icon`)
  and `codesign` (to re-sign itself) — both ship with Xcode / Command Line
  Tools. Anyone who makes `.icon` files in Icon Composer already has Xcode.
- **Run it from a writable location** (e.g. `~/Applications`, Desktop) — *not*
  from a read-only DMG or a locked `/Applications`. The app edits its own bundle
  to swap the icon, so it must be able to write to itself.

## Use

1. Build & launch:
   ```sh
   ./build.sh && open "build/Icon Composter.app"
   ```
2. Drag a `.icon` onto the window. The app compiles it in, re-signs, and
   relaunches (~2 s). The Dock now shows your icon.
3. **Appearance** button → opens System Settings › Appearance so you can flip
   Default / Dark / Clear / Tinted and light/dark. The Dock icon restyles live.
4. **Reset** → restores the built-in default icon and relaunches.

## How it works

A manually-set `applicationIconImage` (or a QuickLook render) never gets the
system's Liquid Glass / Clear / Tinted treatment — that's applied by the system
**only to a real compiled app-icon resource**. So on each drop the app:

1. Runs `actool` to compile the `.icon` → `Assets.car` + `AppIcon.icns`.
2. Drops those into its own bundle (`CFBundleIconName = AppIcon`).
3. Re-signs ad-hoc, re-registers with LaunchServices, and relaunches itself.

The Dock then renders it natively and responds to every appearance setting.

## Sending it to teammates

The build is **ad-hoc signed** (no Developer ID), so the first launch on
another Mac trips Gatekeeper. To install:

1. Unzip and move **Icon Composter.app** to `~/Applications` (or Desktop).
2. **Right-click the app → Open → Open** (only needed once). Or, in Terminal:
   ```sh
   xattr -dr com.apple.quarantine "/path/to/Icon Composter.app"
   ```
3. Drop a `.icon` and go.

> Proper notarization (no warning at all) would require an Apple Developer ID
> and re-architecting the self-modifying bundle — out of scope for an internal
> tool. See the project notes if you want to pursue it.

## Releasing a new version

One command — bumps the version, builds, zips, and publishes a GitHub release
with the zip attached:

```sh
./release.sh v1.1
```

The download link stays the same (`…/releases/latest/download/Icon-Composter.zip`),
so teammates always get the newest build from the same URL.

## Files

- `Sources/IconPreviewApp.swift` — app entry, Open-With handling
- `Sources/ContentView.swift` — small window, drag-and-drop, Appearance/Reset buttons
- `Sources/IconModel.swift` — state + install/reset orchestration
- `Sources/IconInstaller.swift` — `actool` compile → bundle injection → re-sign → relaunch
- `Resources/DefaultAppIcon.icon` — the built-in default app icon
- `Info.plist`, `build.sh` — bundle + build script (arm64, macOS 26)
