import SwiftUI

struct ContentView: View {
    @StateObject private var model = IconModel.shared
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 14) {
            dropZone
            if model.hasCustomIcon && !model.isWorking {
                footer
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Fill edge-to-edge with a plain rect; the window's own rounded
            // corner mask does the rounding (a RoundedRectangle here would add
            // a second, mismatched corner inside the window corner).
            Color.clear
                .glassEffect(.regular, in: Rectangle())
                .ignoresSafeArea()
        }
        .background(WindowConfigurator())
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            Task { await model.load(url: url) }
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                            style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [7, 5])
                        )
                )

            if model.isWorking {
                VStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(model.status)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else if model.hasCustomIcon, let preview = model.preview {
                Image(nsImage: preview)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 168, height: 168)
                    .padding(12)
            } else {
                emptyState
            }
        }
        .frame(width: 228, height: 228)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                Text("Icon Composter")
                    .font(.system(size: 15, weight: .semibold))
                Text("Toss your .icon in here\nand watch it get all glassy ✨")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(model.fileName ?? "Your icon")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 8) {
                Button {
                    model.openAppearanceSettings()
                } label: {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }
                .help("Open System Settings › Appearance to switch Default / Dark / Clear / Tinted")

                Button(role: .destructive) {
                    model.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.uturn.backward")
                }
                .help("Restore the default app icon")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .labelStyle(.titleAndIcon)
            .font(.system(size: 10))
        }
        .frame(height: 44)
    }
}
