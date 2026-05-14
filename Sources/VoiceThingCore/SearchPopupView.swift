import SwiftUI

public struct SearchPopupView: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState private var searchFocused: Bool

    public var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 0) {
                header

                Divider().opacity(0.45)

                if viewModel.showSettings {
                    settings
                } else {
                    results
                }

                footer
            }
            .padding(14)
        }
        .frame(width: 680, height: 520)
        .onAppear {
            searchFocused = true
        }
        .onChange(of: viewModel.query) { _, _ in
            viewModel.queryDidChange()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)

            TextField("Search audio clips", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .medium))
                .focused($searchFocused)

            Button {
                viewModel.showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Settings")

            Button {
                viewModel.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Sound Source")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Image(systemName: "bolt.circle")
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MyInstants")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Public meme sound pages, no API key or account.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Global Shortcut")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ShortcutRecorderView(shortcut: $viewModel.shortcut) { shortcut in
                        viewModel.setShortcut(shortcut)
                    }
                    .frame(width: 180, height: 30)

                    Button {
                        viewModel.resetShortcut()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }

                    Spacer()
                }
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.showSettings = false
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
                .keyboardShortcut(.return)

                Button {
                    viewModel.openSoundSource()
                } label: {
                    Label("Browse Source", systemImage: "safari")
                }

                Button {
                    viewModel.openAccessibilitySettings()
                } label: {
                    Label("Accessibility", systemImage: "hand.raised")
                }

                Spacer()

                Button(role: .destructive) {
                    viewModel.quit()
                } label: {
                    Label("Quit", systemImage: "power")
                }
            }

            Text("Search results are parsed from public MyInstants pages and downloaded as MP3 audio files.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("Click the shortcut field, then press the key combo you want. Use at least one modifier.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(18)
    }

    private var results: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .searching:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView("Search Failed", systemImage: "exclamationmark.triangle", description: Text(message))
            case .empty:
                ContentUnavailableView("No Clips", systemImage: "waveform.slash")
            case .idle where viewModel.displayedClips.isEmpty:
                ContentUnavailableView("Search Meme Sounds", systemImage: "waveform")
            default:
                clipList
            }
        }
    }

    private var clipList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(viewModel.displayedClips.enumerated()), id: \.element.id) { index, clip in
                        ClipRow(
                            clip: clip,
                            isSelected: index == viewModel.selectedIndex,
                            isPreviewing: viewModel.isPreviewing(clip),
                            isBusy: viewModel.isBusy(clip),
                            onSelect: { viewModel.select(clip) },
                            onPreview: { viewModel.togglePreview(clip) },
                            onFavorite: { viewModel.toggleFavorite(clip) }
                        )
                        .id(clip.id)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
            }
            .onChange(of: viewModel.selectedIndex) { _, index in
                let items = viewModel.displayedClips
                guard items.indices.contains(index) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(items[index].id, anchor: .center)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
            } else if viewModel.showSettings {
                Text("No account required")
                    .foregroundStyle(.secondary)
            } else {
                Text(viewModel.displayedClips.isEmpty ? "" : "\(viewModel.displayedClips.count) clips")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .font(.system(size: 12))
        .padding(.horizontal, 6)
        .padding(.top, 10)
    }
}

private struct ClipRow: View {
    let clip: MemeClip
    let isSelected: Bool
    let isPreviewing: Bool
    let isBusy: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPreview) {
                Image(systemName: isPreviewing ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help(isPreviewing ? "Pause" : "Preview")

            VStack(alignment: .leading, spacing: 4) {
                Text(clip.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isBusy {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 28, height: 28)
            }

            Button(action: onFavorite) {
                Image(systemName: clip.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(clip.isFavorite ? .yellow : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(clip.isFavorite ? "Unfavorite" : "Favorite")

            Button(action: onSelect) {
                Image(systemName: "arrow.turn.down.left")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Paste")
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var subtitle: String {
        let tags = clip.tags.prefix(3).joined(separator: ", ")
        let duration = clip.duration.map { Self.durationFormatter.string(from: $0) ?? "" } ?? ""
        let attribution = clip.category ?? ""

        if !duration.isEmpty, !attribution.isEmpty, !tags.isEmpty {
            return "\(duration) • \(attribution) • \(tags)"
        }
        if !attribution.isEmpty, !tags.isEmpty {
            return "\(attribution) • \(tags)"
        }
        if !duration.isEmpty, !tags.isEmpty {
            return "\(duration) • \(tags)"
        }
        if !attribution.isEmpty {
            return attribution
        }
        return tags.isEmpty ? clip.soundURL.host(percentEncoded: false) ?? "Audio" : tags
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
    }
}

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
