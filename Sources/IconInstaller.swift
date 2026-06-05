import AppKit

/// Installs a dropped `.icon` as the app's *real* compiled app icon, then
/// relaunches. Only a genuine app-icon resource gets the system's Liquid Glass
/// + "Icon & widget style" (Default/Dark/Clear/Tinted) treatment in the Dock —
/// a manually-set `applicationIconImage` does not. So we compile the icon into
/// our own bundle and restart.
enum IconInstaller {

    enum InstallError: LocalizedError {
        case step(String, Int32, String)
        case missingXcode
        var errorDescription: String? {
            switch self {
            case .step(let name, let code, let out):
                return "\(name) failed (\(code)). \(out)"
            case .missingXcode:
                return "Needs Xcode — it uses actool to render the .icon. Install Xcode, then try again."
            }
        }
    }

    private static let lsregister =
        "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

    /// Compile `iconURL` into our bundle as AppIcon, re-sign, re-register, relaunch.
    static func installAndRelaunch(iconURL: URL) throws {
        try ensureXcodeAvailable()
        let bundleURL = Bundle.main.bundleURL
        let resources = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let fm = FileManager.default

        let work = fm.temporaryDirectory.appendingPathComponent("IconInstall-\(UUID().uuidString)", isDirectory: true)
        let out = work.appendingPathComponent("out", isDirectory: true)
        try fm.createDirectory(at: out, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        // actool keys the app icon off the input file's base name.
        let iconCopy = work.appendingPathComponent("AppIcon.icon")
        try fm.copyItem(at: iconURL, to: iconCopy)

        // 1. Compile the .icon → Assets.car (+ AppIcon.icns fallback).
        try run("actool", "/usr/bin/xcrun", [
            "actool",
            "--compile", out.path,
            "--app-icon", "AppIcon",
            "--platform", "macosx",
            "--minimum-deployment-target", "26.0",
            "--output-partial-info-plist", work.appendingPathComponent("p.plist").path,
            iconCopy.path,
        ])

        // 2. Drop the compiled assets into our bundle.
        for name in ["Assets.car", "AppIcon.icns"] {
            let src = out.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else {
                throw InstallError.step("compile", -1, "\(name) not produced")
            }
            let dst = resources.appendingPathComponent(name)
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
            try fm.copyItem(at: src, to: dst)
        }

        finalizeAndRelaunch(bundleURL: bundleURL)
    }

    /// Restore the app's built-in default icon (stashed at build time).
    static func resetAndRelaunch() throws {
        let resources = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let defaults = resources.appendingPathComponent("Default", isDirectory: true)
        let fm = FileManager.default
        for name in ["Assets.car", "AppIcon.icns"] {
            let src = defaults.appendingPathComponent(name)
            let dst = resources.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else { continue }
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
            try fm.copyItem(at: src, to: dst)
        }
        finalizeAndRelaunch(bundleURL: Bundle.main.bundleURL)
    }

    // MARK: - Plumbing

    /// `actool` ships only with Xcode (not the Command Line Tools alone), so
    /// fail early with a clear message if it isn't reachable.
    private static func ensureXcodeAvailable() throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        p.arguments = ["-f", "actool"]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        do { try p.run() } catch { throw InstallError.missingXcode }
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw InstallError.missingXcode }
    }

    private static func finalizeAndRelaunch(bundleURL: URL) {
        // Re-sign (modifying Resources breaks the ad-hoc seal) and re-register
        // so LaunchServices/the Dock pick up the new icon, then relaunch.
        _ = try? run("codesign", "/usr/bin/codesign", ["--force", "--deep", "--sign", "-", bundleURL.path])
        _ = try? run("lsregister", lsregister, ["-f", bundleURL.path])

        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 0.4; /usr/bin/open \"\(bundleURL.path)\""]
        try? relaunch.run()
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }

    @discardableResult
    private static func run(_ name: String, _ launchPath: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        if p.terminationStatus != 0 {
            throw InstallError.step(name, p.terminationStatus, output)
        }
        return output
    }
}
