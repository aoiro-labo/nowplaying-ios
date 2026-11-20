import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @State private var track: Track?
    @State private var isPlaying = false
    @State private var postText: String = ""
    @State private var artwork: UIImage?
    @State private var artworkData: Data?
    @State private var lastMatch: ITunesMatch?
    @State private var status: String = ""
    @State private var postStatus: String = ""
    @State private var history: [HistoryItem] = []
    @State private var loading = false
    @State private var posting = false
    @State private var showShare = false
    @State private var showSettings = false

    private let settings = NPSettings()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let img = artwork {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .cornerRadius(12)
                    }
                    if let t = track {
                        VStack(spacing: 6) {
                            Text(t.title).font(.headline).multilineTextAlignment(.center)
                            Text(t.artistsJoined).font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Text(t.album).font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                badge(t.source == "spotify" ? "Spotify" : "Apple Music")
                                badge(isPlaying ? NSLocalizedString("Playing", comment: "")
                                                : NSLocalizedString("Paused", comment: ""))
                            }
                        }
                        VStack(alignment: .trailing, spacing: 4) {
                            TextEditor(text: $postText)
                                .font(.footnote)
                                .frame(minHeight: 84)
                                .padding(6)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(8)
                                .autocorrectionDisabled()
                            Text("X ≈ \(xWeightedCount(postText)) / 280")
                                .font(.caption2)
                                .foregroundStyle(xWeightedCount(postText) > 280 ? .red : .secondary)
                        }
                        if settings.formatPresets.count > 1 {
                            Menu {
                                ForEach(settings.formatPresets, id: \.self) { preset in
                                    Button(preset) { applyPreset(preset) }
                                }
                            } label: {
                                Label("Switch format", systemImage: "textformat")
                                    .font(.caption)
                            }
                        }
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
                    if track != nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                destButton("X app") { openXApp() }
                                if isConfigured("xapi") {
                                    destButton("X (API)") { Task { await postDirect("xapi") } }
                                }
                                if isConfigured("bluesky") {
                                    destButton("Bluesky") { Task { await postDirect("bluesky") } }
                                }
                                if isConfigured("mastodon") {
                                    destButton("Mastodon") { Task { await postDirect("mastodon") } }
                                }
                                if isConfigured("misskey") {
                                    destButton("Misskey") { Task { await postDirect("misskey") } }
                                }
                            }
                        }
                        .disabled(posting)
                    }
                    if loading || posting { ProgressView() }
                    if !postStatus.isEmpty {
                        Text(postStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    if !history.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("History")
                                .font(.subheadline).bold()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(history, id: \.date) { item in
                                Button {
                                    Task { await restore(item) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.track.title).font(.footnote).bold()
                                            .lineLimit(1)
                                        Text(item.track.artistsJoined).font(.caption)
                                            .foregroundStyle(.secondary).lineLimit(1)
                                        Text(item.date, style: .time).font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.08))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
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
            .sheet(isPresented: $showSettings, onDismiss: { history = settings.history }) {
                SettingsView()
            }
            .task { await refresh() }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2).bold()
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(6)
    }

    private func destButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.caption)
            .buttonStyle(.bordered)
    }

    private func isConfigured(_ dest: String) -> Bool {
        switch dest {
        case "xapi":
            return !settings.xConsumerKey.isEmpty && !settings.xConsumerSecret.isEmpty
                && !settings.xAccessToken.isEmpty && !settings.xAccessTokenSecret.isEmpty
        case "bluesky":
            return !settings.bskyHandle.isEmpty && !settings.bskyAppPassword.isEmpty
        case "mastodon":
            return !settings.mastodonInstance.isEmpty && !settings.mastodonToken.isEmpty
        case "misskey":
            return !settings.misskeyInstance.isEmpty && !settings.misskeyToken.isEmpty
        default:
            return false
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

    private func applyPreset(_ preset: String) {
        settings.format = preset
        guard let t = track else { return }
        postText = Composer.compose(track: t, itunes: lastMatch, settings: settings).text
    }

    private func restore(_ item: HistoryItem) async {
        track = item.track
        isPlaying = false
        postText = item.text
        status = ""
        postStatus = ""
        let (match, artData) = await ITunesMatcher.search(track: item.track, quality: settings.artworkQuality)
        lastMatch = match
        artworkData = settings.artworkEnabled ? artData : nil
        artwork = artworkData.flatMap { UIImage(data: $0) }
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        guard let resolved = await Resolver.resolveDetailed(settings: settings) else {
            track = nil
            artwork = nil
            artworkData = nil
            postText = ""
            history = settings.history
            status = settings.source == "spotify" || (settings.refreshToken.isEmpty && settings.source == "auto")
                ? NSLocalizedString("Nothing is playing (Spotify needs a token in Settings)", comment: "")
                : NSLocalizedString("Nothing is playing", comment: "")
            return
        }
        let t = resolved.track
        let (match, artData) = await ITunesMatcher.search(track: t, quality: settings.artworkQuality)
        let composed = Composer.compose(track: t, itunes: match, settings: settings)
        track = t
        isPlaying = resolved.isPlaying
        lastMatch = match
        postText = composed.text
        artworkData = settings.artworkEnabled ? artData : nil
        artwork = artworkData.flatMap { UIImage(data: $0) }
        status = ""
        settings.cachedTrack = t
        settings.addHistory(track: t, text: composed.text)
        history = settings.history
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Approximate X (Twitter) weighted character count: URLs count as 23,
    /// wide (CJK / emoji) characters count as 2, everything else as 1.
    private func xWeightedCount(_ text: String) -> Int {
        var rest = text
        var count = 0
        if let regex = try? NSRegularExpression(pattern: "https?://\\S+") {
            let ns = rest as NSString
            let matches = regex.matches(in: rest, range: NSRange(location: 0, length: ns.length))
            count += matches.count * 23
            rest = regex.stringByReplacingMatches(in: rest,
                                                  range: NSRange(location: 0, length: ns.length),
                                                  withTemplate: "")
        }
        for scalar in rest.unicodeScalars {
            count += isWide(scalar) ? 2 : 1
        }
        return count
    }

    private func isWide(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x1100...0x11FF, 0x2E80...0x9FFF, 0xA000...0xA4CF, 0xAC00...0xD7A3,
             0xF900...0xFAFF, 0xFE30...0xFE4F, 0xFF00...0xFF60, 0xFFE0...0xFFE6,
             0x1F300...0x1F9FF, 0x20000...0x2FFFD, 0x30000...0x3FFFD:
            return true
        default:
            return false
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
