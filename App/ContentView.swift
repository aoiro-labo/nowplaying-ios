import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @State private var track: Track?
    @State private var postText: String = ""
    @State private var artwork: UIImage?
    @State private var artworkData: Data?
    @State private var status: String = ""
    @State private var postStatus: String = ""
    @State private var loading = false
    @State private var posting = false
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
                    Menu {
                        Button("Post to X (app)") { openXApp() }
                        Button("Post to X (API)") { Task { await postDirect("xapi") } }
                        Button("Post to Bluesky") { Task { await postDirect("bluesky") } }
                        Button("Post to Mastodon") { Task { await postDirect("mastodon") } }
                        Button("Post to Misskey") { Task { await postDirect("misskey") } }
                    } label: {
                        Label("Direct", systemImage: "paperplane")
                    }
                    .buttonStyle(.bordered)
                    .disabled(track == nil || posting)
                }
                if loading || posting { ProgressView() }
                if !postStatus.isEmpty {
                    Text(postStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
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

    /// Opens the X app compose screen with the text (images cannot be attached
    /// through the URL scheme; use the share sheet or the X API for images).
    private func openXApp() {
        let enc = postText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "twitter://post?message=\(enc)") {
            openURL(url) { accepted in
                if !accepted, let web = URL(string: "https://twitter.com/intent/tweet?text=\(enc)") {
                    openURL(web)
                }
            }
        }
    }

    private func postDirect(_ dest: String) async {
        posting = true
        postStatus = ""
        defer { posting = false }
        do {
            let img = settings.artworkEnabled ? artworkData : nil
            switch dest {
            case "xapi": try await XPoster.post(text: postText, imageData: img, s: settings)
            case "bluesky": try await BlueskyPoster.post(text: postText, imageData: img, s: settings)
            case "mastodon": try await MastodonPoster.post(text: postText, imageData: img, s: settings)
            case "misskey": try await MisskeyPoster.post(text: postText, imageData: img, s: settings)
            default: break
            }
            postStatus = NSLocalizedString("Posted", comment: "")
        } catch {
            postStatus = error.localizedDescription
        }
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        guard let t = await Resolver.resolve(settings: settings) else {
            track = nil
            artwork = nil
            artworkData = nil
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
        artworkData = settings.artworkEnabled ? artData : nil
        artwork = artworkData.flatMap { UIImage(data: $0) }
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
