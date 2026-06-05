import SwiftUI
import AppKit

/// Shared state for the loaded icon. Dropping an icon compiles it into the app
/// bundle as the *real* app icon and relaunches — so the Dock renders it with
/// full system styling (light/dark + Default/Dark/Clear/Tinted), live, with no
/// further work from us.
@MainActor
final class IconModel: ObservableObject {
    static let shared = IconModel()

    @Published var preview: NSImage?
    @Published var fileName: String?
    @Published var status = "Drop a .icon here"
    @Published var isWorking = false
    @Published var hasCustomIcon = false

    private let lastIconKey = "lastIconPath"

    private init() {
        showInstalledPreview()
    }

    func load(url: URL) async {
        isWorking = true
        status = "Installing & relaunching…"
        UserDefaults.standard.set(url.path, forKey: lastIconKey)
        Task.detached(priority: .userInitiated) {
            do {
                try IconInstaller.installAndRelaunch(iconURL: url)  // terminates the app
            } catch {
                await MainActor.run {
                    let m = IconModel.shared
                    m.isWorking = false
                    m.status = error.localizedDescription
                    NSSound.beep()
                }
            }
        }
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: lastIconKey)
        isWorking = true
        status = "Resetting…"
        try? IconInstaller.resetAndRelaunch()  // terminates the app
    }

    func openAppearanceSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Appearance-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// If a custom icon has been installed, show a reference thumbnail of it.
    /// In the default (empty) state we show nothing — just the drop prompt.
    private func showInstalledPreview() {
        guard let path = UserDefaults.standard.string(forKey: lastIconKey) else { return }
        hasCustomIcon = true
        fileName = (path as NSString).lastPathComponent
        let icns = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/AppIcon.icns")
        if FileManager.default.fileExists(atPath: icns.path),
           let image = NSImage(contentsOf: icns) {
            preview = image
        }
    }
}
