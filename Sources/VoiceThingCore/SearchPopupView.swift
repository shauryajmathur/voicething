import SwiftUI

public struct SearchPopupView: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState private var searchFocused: Bool
    @State private var editingShortcut = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ink = Color.white.opacity(0.92)

    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.showOnboarding {
                onboarding
            } else {
                header
                if viewModel.isExpanded {
                    Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                    if viewModel.showSettings { settings }
                    else if let clip = viewModel.voiceClip { voiceComposer(clip) }
                    else { library }
                    footer
                }
            }
        }
        .frame(width: 760, height: viewModel.panelHeight)
        .background {
            ZStack {
                VisualEffectView()
                Color(white: 0.065).opacity(0.88)
                LinearGradient(colors: [.white.opacity(0.025), .clear, .black.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: viewModel.isExpanded ? 24 : 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: viewModel.isExpanded ? 24 : 28, style: .continuous)
                .strokeBorder(LinearGradient(stops: [
                    .init(color: .white.opacity(0.32), location: 0),
                    .init(color: Color(red: 0.59, green: 0.68, blue: 0.76).opacity(0.25), location: 0.35),
                    .init(color: .white.opacity(0.09), location: 0.65),
                    .init(color: Color(red: 0.79, green: 0.74, blue: 0.66).opacity(0.26), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.4)
                .allowsHitTesting(false)
        }
        .foregroundStyle(ink)
        .preferredColorScheme(.dark)
        .tint(.white)
        .highPriorityGesture(DragGesture(minimumDistance: 8)
            .onChanged { _ in viewModel.onPanelDrag?(true) }
            .onEnded { _ in viewModel.onPanelDrag?(false) })
        .onAppear { searchFocused = !viewModel.showOnboarding }
        .onChange(of: viewModel.showOnboarding) { _, showing in searchFocused = !showing }
        .onChange(of: viewModel.showSettings) { _, showing in searchFocused = !showing }
        .onChange(of: viewModel.library) { _, _ in searchFocused = true }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: viewModel.isExpanded)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSImage(contentsOf: Bundle.module.url(forResource: "VoiceThingMark", withExtension: "png", subdirectory: "Brand")!)!)
                .resizable().scaledToFit()
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 30, height: 40)
                .overlay { PanelDragHandle() }
                .help("Drag to move VoiceThing")
            TextField(viewModel.library == .sounds ? "Search sounds…" : "Search recordings…", text: $viewModel.query)
                .font(.system(size: 23, weight: .regular))
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .disabled(viewModel.isRecording || viewModel.isSending)
                .accessibilityLabel("Search sounds and recordings")
                .onAppear { searchFocused = true }
            if !viewModel.query.isEmpty {
                iconButton("xmark.circle.fill", help: "Clear search") { viewModel.query = "" }
            }
            Menu {
                Button("Sounds") { viewModel.changeLibrary(.sounds) }
                Button("Audio Recordings") { viewModel.changeLibrary(.recordings) }
                Divider()
                Button("Settings") { viewModel.showSettings.toggle() }
                Button("Welcome to VoiceThing") { viewModel.onboardingStep = 0; viewModel.showOnboarding = true }
                Divider()
                Button("Quit VoiceThing") { viewModel.quit() }
            } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.45)).frame(width: 30, height: 30)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Library and settings")
            Button { editingShortcut = true } label: {
                keycap(viewModel.shortcut.displayName
                    .replacingOccurrences(of: "Control+", with: "⌃ ")
                    .replacingOccurrences(of: "Option+", with: "⌥ ")
                    .replacingOccurrences(of: "Shift+", with: "⇧ ")
                    .replacingOccurrences(of: "Command+", with: "⌘ "))
            }
            .buttonStyle(.plain)
            .help("Change shortcut")
            .popover(isPresented: $editingShortcut, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Change shortcut").font(.system(size: 12, weight: .medium))
                    ShortcutRecorderView(shortcut: $viewModel.shortcut) {
                        viewModel.setShortcut($0)
                        editingShortcut = false
                        searchFocused = true
                    }
                    .frame(width: 160, height: 30)
                }
                .padding(16)
                .preferredColorScheme(.dark)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 78)
    }

    private var library: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(SearchViewModel.Library.allCases, id: \.self) { item in
                    Button { viewModel.changeLibrary(item) } label: {
                        Text(item.rawValue).font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(viewModel.library == item ? .white.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain)
                }
                Spacer()
                if viewModel.library == .recordings {
                    if viewModel.isRecording {
                        Button("Discard", role: .destructive) { viewModel.cancelRecording() }.buttonStyle(.plain)
                    }
                    Button { viewModel.toggleRecording() } label: {
                        Label(viewModel.isRecording ? "Finish recording" : "New recording", systemImage: viewModel.isRecording ? "stop.circle.fill" : "mic")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(viewModel.isRecording ? Color.red.opacity(0.9) : Color.white.opacity(0.7))
                    }.buttonStyle(.plain).disabled(viewModel.isRequestingMicrophone)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 12)

            if viewModel.isRecording {
                VStack(spacing: 18) {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Image(systemName: "record.circle").font(.system(size: 42, weight: .ultraLight)).foregroundStyle(.red.opacity(0.8))
                    }
                    Text("Recording your microphone").font(.system(size: 20, weight: .medium))
                    Text("Finish when you’re ready. Maximum 5 minutes.").font(.system(size: 13)).foregroundStyle(.secondary)
                    Button("Finish recording") { viewModel.toggleRecording() }.buttonStyle(GlassButtonStyle(prominent: true))
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.library == .sounds, case .searching = viewModel.state {
                emptyState("Finding your sound", detail: "Searching MyInstants…", symbol: "waveform", loading: true)
            } else if viewModel.library == .sounds, case .failed(let message) = viewModel.state {
                VStack(spacing: 12) {
                    emptyState("Couldn’t load sounds", detail: message, symbol: "wifi.exclamationmark")
                    Button("Try again") { viewModel.queryDidChange() }.buttonStyle(GlassButtonStyle())
                }.padding(.bottom, 30)
            } else if viewModel.displayedClips.isEmpty {
                emptyState(viewModel.library == .recordings ? "Your audio, ready to go" : "No sounds found",
                           detail: viewModel.library == .recordings ? "Save a sound here, or make a recording of your own." : "Try another word or a different spelling.",
                           symbol: viewModel.library == .recordings ? "waveform.path" : "magnifyingglass")
            } else {
                clipList
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var clipList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(Array(viewModel.displayedClips.enumerated()), id: \.element.id) { index, clip in
                        HStack(spacing: 13) {
                            Button { viewModel.togglePreview(clip) } label: {
                                Image(systemName: viewModel.isPreviewing(clip) ? "stop.fill" : "play.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(width: 32, height: 32)
                                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
                            }.buttonStyle(.plain).help("Preview \(clip.name)").accessibilityLabel("Preview \(clip.name)")
                            Button { viewModel.select(clip) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(clip.name).font(.system(size: 14, weight: .medium)).lineLimit(1)
                                    Text(clip.category ?? "Audio").font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            if viewModel.isBusy(clip) { ProgressView().controlSize(.small) }
                            if !clip.soundURL.isFileURL {
                                iconButton(clip.isFavorite ? "star.fill" : "star", help: "Favorite \(clip.name)") { viewModel.toggleFavorite(clip) }
                                    .foregroundStyle(clip.isFavorite ? Color.yellow.opacity(0.8) : Color.white.opacity(0.35))
                            }
                            Menu {
                                Button("Choose chat app") { viewModel.chooseChatTarget(for: clip) }
                                Button("Copy audio file") { viewModel.copyClip(clip) }
                                if !clip.soundURL.isFileURL { Button("Save to Audio Recordings") { viewModel.saveRecording(clip) } }
                                if let source = clip.sourceURL { Link("Open source", destination: source) }
                                Divider()
                                Button("Delete", role: .destructive) { viewModel.deleteClip(clip) }
                            } label: { Image(systemName: "ellipsis").frame(width: 24, height: 28) }
                            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                            Image(systemName: "return").font(.system(size: 12)).foregroundStyle(.white.opacity(index == viewModel.selectedIndex ? 0.65 : 0.12))
                        }
                        .padding(.horizontal, 14).frame(height: 58)
                        .background(.white.opacity(index == viewModel.selectedIndex ? 0.085 : 0), in: RoundedRectangle(cornerRadius: 10))
                        .id(clip.id)
                    }
                }.padding(.horizontal, 12).padding(.bottom, 10)
            }
            .onChange(of: viewModel.selectedIndex) { _, index in
                let clips = viewModel.displayedClips
                if clips.indices.contains(index) { proxy.scrollTo(clips[index].id, anchor: .center) }
            }
        }
    }

    private func voiceComposer(_ clip: MemeClip) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Button { viewModel.cancelSelection() } label: { Label("Back", systemImage: "chevron.left").font(.system(size: 12)) }.buttonStyle(.plain)
                Spacer()
                Menu {
                    ForEach(viewModel.availableChatApplications, id: \.processIdentifier) { application in
                        Button(application.localizedName ?? "Chat app") { viewModel.chooseTargetApplication(application) }
                    }
                } label: {
                    Label("Send in \(viewModel.targetName)", systemImage: "waveform").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                }.menuStyle(.borderlessButton).fixedSize().help("Choose the app containing your chat")
            }
            HStack(spacing: 18) {
                Image(systemName: "waveform").font(.system(size: 32, weight: .light))
                    .frame(width: 68, height: 68).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 19))
                VStack(alignment: .leading, spacing: 7) {
                    Text(clip.name).font(.system(size: 23, weight: .medium)).lineLimit(2)
                    Text("Enter to send a voice message in \(viewModel.targetName).")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
                }
            }
            Text("Send this sound through the chat’s voice recorder.")
                .font(.system(size: 15)).foregroundStyle(.white.opacity(0.5))
            Text("Option–Space cancels while the audio is preparing.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.35))
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                if !viewModel.hasAccessibility {
                    Button("Enable Accessibility") { viewModel.requestAccessibility(); viewModel.openAccessibilitySettings() }.buttonStyle(GlassButtonStyle(prominent: true))
                } else {
                    Button("Send voice message") { viewModel.select(clip) }.buttonStyle(GlassButtonStyle(prominent: true))
                        .disabled(viewModel.busyClipID != nil)
                }
                Spacer()
                if !clip.soundURL.isFileURL {
                    Button("Save recording") { viewModel.saveRecording(clip) }.buttonStyle(GlassButtonStyle())
                }
                Menu {
                    Button("Copy audio file") { viewModel.copyClip(clip) }
                    Button("Send voice message") { viewModel.select(clip) }
                } label: { Image(systemName: "ellipsis").padding(8) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
        }.padding(26).frame(maxHeight: .infinity)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Settings").font(.system(size: 21, weight: .medium))
                Spacer()
                Button("Done") { viewModel.showSettings = false }.buttonStyle(GlassButtonStyle())
            }
            HStack {
                settingsLabel("Global shortcut", "Open VoiceThing from any app.")
                Spacer()
                ShortcutRecorderView(shortcut: $viewModel.shortcut) { viewModel.setShortcut($0) }.frame(width: 160, height: 30)
                Button("Reset") { viewModel.resetShortcut() }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Divider().overlay(.white.opacity(0.04))
            HStack {
                settingsLabel("Keep sounds on this Mac", "Off by default. Keeps downloaded sounds, favorites and history.")
                Spacer()
                Toggle("Keep sounds on this Mac", isOn: Binding(get: { viewModel.retainsAudio }, set: { viewModel.setRetention($0) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small).disabled(viewModel.busyClipID != nil || viewModel.isClearingStorage)
            }
            HStack(spacing: 16) {
                Button("Clear cached sounds & history") { viewModel.clearStoredAudio() }.buttonStyle(.plain)
                    .disabled(viewModel.busyClipID != nil || viewModel.isClearingStorage)
                Button("Open Audio Recordings") { viewModel.revealRecordings() }.buttonStyle(.plain)
            }.font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
            Text("With storage off, sounds use a temporary cache capped at 64 MB and expire after 24 hours. Recordings you explicitly save remain until deleted.")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.35)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack {
                Button("Accessibility for voice messages") { viewModel.requestAccessibility(); viewModel.openAccessibilitySettings() }.buttonStyle(.plain)
                Spacer()
                Button("Sound source · MyInstants") { viewModel.openSoundSource() }.buttonStyle(.plain)
                Button("Quit") { viewModel.quit() }.buttonStyle(.plain)
            }.font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
        }.padding(26).frame(maxHeight: .infinity)
    }

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("VoiceThing", systemImage: "waveform").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<3) { step in Capsule().fill(.white.opacity(step == viewModel.onboardingStep ? 0.65 : 0.12)).frame(width: step == viewModel.onboardingStep ? 22 : 7, height: 4) }
                }
            }
            Spacer()
            Group {
                switch viewModel.onboardingStep {
                case 0:
                    HStack(spacing: 10) {
                        Text("⌥").frame(width: 68, height: 62)
                        Text("space").frame(width: 140, height: 62)
                    }
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .background { RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.04)).blur(radius: 20) }
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.15), lineWidth: 1) }
                    .padding(.bottom, 26)
                    Text("Welcome to VoiceThing.\nMake yourself heard.").font(.system(size: 34, weight: .medium)).tracking(-0.8)
                    Text("Find a sound, hear it, and send it as a voice message.\nRight where the conversation is happening.")
                        .font(.system(size: 15)).lineSpacing(5).foregroundStyle(.white.opacity(0.45)).padding(.top, 12)
                case 1:
                    Image(systemName: "paperplane").font(.system(size: 43, weight: .ultraLight)).padding(.bottom, 24)
                    Text("Straight into the chat.").font(.system(size: 34, weight: .medium)).tracking(-0.8)
                    Text("Press Enter to record and send the sound through your chat’s microphone. Keep the chat focused until it finishes.")
                        .font(.system(size: 15)).lineSpacing(5).foregroundStyle(.white.opacity(0.45)).padding(.top, 12)
                    HStack(spacing: 14) {
                        Button(viewModel.hasAccessibility ? "Accessibility enabled" : "Enable Accessibility") { viewModel.requestAccessibility(); viewModel.openAccessibilitySettings() }
                            .buttonStyle(GlassButtonStyle(prominent: true)).disabled(viewModel.hasAccessibility)
                    }.padding(.top, 22)
                default:
                    Image(systemName: "externaldrive.badge.checkmark").font(.system(size: 43, weight: .ultraLight)).padding(.bottom, 24)
                    Text("Keep only what you choose.").font(.system(size: 32, weight: .medium)).tracking(-0.8)
                    Text("Search and play without building a permanent sound library. Turn storage on if you’d like sounds and history to stay on this Mac.")
                        .font(.system(size: 15)).lineSpacing(5).foregroundStyle(.white.opacity(0.45)).padding(.top, 12)
                    Toggle("Keep sounds on this Mac", isOn: Binding(get: { viewModel.retainsAudio }, set: { viewModel.setRetention($0) }))
                        .toggleStyle(.switch).font(.system(size: 13)).padding(.top, 22)
                    Text("Explicitly saved audio recordings are always kept until you delete them.")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.3)).padding(.top, 8)
                }
            }
            .id(viewModel.onboardingStep)
            Spacer()
            HStack {
                if viewModel.onboardingStep > 0 {
                    Button("Back") { viewModel.onboardingStep -= 1 }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.45))
                } else {
                    Text("Made for the moment.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
                Button(viewModel.onboardingStep == 2 ? "Start using VoiceThing" : "Continue") {
                    if viewModel.onboardingStep < 2 { viewModel.onboardingStep += 1 }
                    else { viewModel.completeOnboarding() }
                }.buttonStyle(GlassButtonStyle(prominent: true))
            }.font(.system(size: 13))
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if viewModel.busyClipID != nil { ProgressView().controlSize(.mini) }
            if let message = viewModel.statusMessage { Text(message).lineLimit(2) }
            else if viewModel.showSettings { Text("VoiceThing 0.2 · Native to macOS") }
            else if viewModel.voiceClip != nil { Text(viewModel.hasAccessibility ? "Ready to send" : "Accessibility setup required") }
            else { Text("\(viewModel.displayedClips.count) \(viewModel.library == .recordings ? "recordings" : "sounds")") }
            Spacer(minLength: 12)
            if viewModel.voiceClip == nil, !viewModel.showSettings, !viewModel.isRecording { keycap("↑ ↓"); Text("navigate"); keycap("↵"); Text("send voice") }
        }
        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.38))
        .padding(.horizontal, 24).frame(height: 44)
        .background(.white.opacity(0.02))
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1) }
    }

    private func emptyState(_ title: String, detail: String, symbol: String, loading: Bool = false) -> some View {
        VStack(spacing: 14) {
            if loading { ProgressView().controlSize(.small).padding(.bottom, 10) }
            else { Image(systemName: symbol).font(.system(size: 34, weight: .ultraLight)).foregroundStyle(.white.opacity(0.35)).padding(.bottom, 5) }
            Text(title).font(.system(size: 18, weight: .medium))
            Text(detail).font(.system(size: 13)).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center).frame(maxWidth: 390)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func instruction(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                .frame(width: 22, height: 22).background(.white.opacity(0.07), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
            }
        }
    }
    private func settingsLabel(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 13, weight: .medium))
            Text(detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
        }
    }
    private func keycap(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.4))
            .padding(.horizontal, 6).padding(.vertical, 4)
            .overlay { RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.12), lineWidth: 1) }
    }
    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 13)).frame(width: 26, height: 28) }
            .buttonStyle(.plain).help(help).accessibilityLabel(help)
    }
}

private struct PanelDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {}

    final class DragView: NSView {
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            window.performDrag(with: event)
            let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
            UserDefaults.standard.set(NSStringFromPoint(topLeft), forKey: "searchPanelTopLeft")
        }
    }
}

private struct GlassButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .foregroundStyle(prominent ? Color.black.opacity(0.85) : Color.white.opacity(0.8))
            .padding(.horizontal, 15).frame(height: 34)
            .background(prominent ? Color(white: configuration.isPressed ? 0.75 : 0.91) : .white.opacity(configuration.isPressed ? 0.13 : 0.065), in: RoundedRectangle(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(prominent ? 0.2 : 0.1), lineWidth: 0.7) }
    }
}

private struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
