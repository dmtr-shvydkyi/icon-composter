import SwiftUI
import AppKit

/// Makes the hosting SwiftUI window fully transparent so the Liquid Glass panel
/// floats over the desktop, and lets the window be dragged by its background
/// (we hide the title bar).
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let probe = NSView()
        DispatchQueue.main.async {
            guard let window = probe.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.hasShadow = true
        }
        return probe
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
