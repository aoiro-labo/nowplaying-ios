import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var track: Track?
    @State private var postText: String = ""
    @State private var artwork: UIImage?
    @State private var status: String = ""
    @State private var loading = false
    @State private var showShare = false
    @State private var showSettings = false

    private let settings = NPSettings()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let img = artwork {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .cornerRadius(12)
                }
                if let t = track {
                    VStack(spacing: 4) {
                        Text(t.title).font(.headline).multilineTextAlignment(.center)
                        Text(t.artistsJoined).font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text(t.album).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(postText)
                        .font(.footnote)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(8)
                } else {
                    Text(status.isEmpty ? NSLocalizedString("Not fetched yet", comment: "") : status)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Label("Fetch", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(loading)
                    Button {
                        showShare = true
                    } label: {
                        Label("Post", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(track == nil)
                }
                if loading { ProgressView() }
                Spacer()
            }
            .padding()
            .navigationTitle("NowPlaying")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(items: shareItems())
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task { await refresh() }
        }
    }

    private func shareItems() -> [Any] {
        var items: [Any] = [postText]
        if settings.artworkEnabled, let img = artwork { items.append(img) }
        return items
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        guard let t = await Resolver.resolve(settings: settings) else {
            track = nil
            artwork = nil
            postText = ""
            status = settings.source == "spotify" || (settings.refreshToken.isEmpty && settings.source == "auto")
                ? NSLocalizedString("Nothing is playing (Spotify needs a token in Settings)", comment: "")
                : NSLocalizedString("Nothing is playing", comment: "")
            return
        }
        let (match, artData) = await ITunesMatcher.search(track: t, quality: settings.artworkQuality)
        let composed = Composer.compose(track: t, itunes: match, settings: settings)
        track = t
        postText = composed.text
        artwork = (settings.artworkEnabled ? artData : nil).flatMap { UIImage(data: $0) }
        status = ""
        settings.cachedTrack = t
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
