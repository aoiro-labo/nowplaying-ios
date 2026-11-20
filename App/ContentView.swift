import SwiftUI
import WidgetKit

extension View {
    /// iOS grouped-list card: secondary grouped background, continuous
    /// rounded corners, standard padding.
    func npCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

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
                VStack(spacing: 20) {
                    if let t = track {
                        nowPlayingCard(t)
                        postTextCard
                    } else if !loading {
                        ContentUnavailableView {
                            Label("No track yet", systemImage: "music.note")
                        } description: {
                            Text(status.isEmpty
                                 ? NSLocalizedString("Tap Fetch to load the current track.", comment: "")
                                 : status)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }

                    actionsRow

                    if track != nil {
                        destinationsRow
                    }

                    if loading || posting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                    if !postStatus.isEmpty {
                        Text(postStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    if !history.isEmpty {
                        historySection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
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

    // MARK: - Sections

    private func nowPlayingCard(_ t: Track) -> some View {
        VStack(spacing: 12) {
            if let img = artwork {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(spacing: 4) {
                Text(t.title)
                    .font(.title3).bold()
                    .multilineTextAlignment(.center)
                Text(t.artistsJoined)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !t.album.isEmpty {
                    Text(t.album)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            HStack(spacing: 6) {
                badge(sourceName(t.source))
                badge(isPlaying ? NSLocalizedString("Playing", comment: "")
                                : NSLocalizedString("Paused", comment: ""),
                      systemImage: isPlaying ? "play.fill" : "pause.fill")
            }
        }
        .frame(maxWidth: .infinity)
        .npCard()
    }

    private var postTextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("Post text")
                Spacer()
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
            }
            TextEditor(text: $postText)
                .font(.body)
                .frame(minHeight: 96)
                .padding(6)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .autocorrectionDisabled()
            HStack {
                Spacer()
                Text("X ≈ \(xWeightedCount(postText)) / 280")
                    .font(.caption2)
                    .foregroundStyle(xWeightedCount(postText) > 280 ? .red : .secondary)
            }
        }
        .npCard()
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            Button {
                Task { await refresh() }
            } label: {
                Label("Fetch", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(loading)

            Button {
                scrobbleIfEnabled()
                showShare = true
            } label: {
                Label("Post", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(track == nil)
        }
    }

    private var destinationsRow: some View {
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

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("History")
                Spacer()
                Button("Clear all") { clearHistory() }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
            ForEach(history, id: \.date) { item in
                Button {
                    Task { await restore(item) }
                } label: {
                    HStack(spacing: 12) {
                        historyThumb(item)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.track.title).font(.subheadline).bold()
                                .lineLimit(1)
                            Text(item.track.artistsJoined).font(.caption)
                                .foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.date, style: .time)
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(sourceName(item.track.source))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .npCard(padding: 10)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Copy post text") {
                        UIPasteboard.general.string = item.text
                    }
                    Button("Delete", role: .destructive) { deleteHistoryItem(item) }
                }
            }
        }
    }

    // MARK: - Small pieces

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption).bold()
            .foregroundStyle(.secondary)
    }

    private func badge(_ text: String, systemImage: String? = nil) -> some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(.caption2).bold()
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }

    private func destButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    private func sourceName(_ source: String) -> String {
        switch source {
        case "spotify": return "Spotify"
        case "lastfm": return "Last.fm"
        default: return "Apple Music"
        }
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
        scrobbleIfEnabled()
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
        scrobbleIfEnabled()
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

    /// Last.fm write-back: on fetch we send updateNowPlaying; on post
    /// actions we scrobble. Both only when the integration is enabled
    /// and a session exists.
    private func scrobbleIfEnabled() {
        guard settings.lastfmScrobble, !settings.lastfmSessionKey.isEmpty,
              let t = track else { return }
        Task { try? await LastFmClient.scrobble(track: t, timestamp: Date(), settings: settings) }
    }

    private func sendNowPlayingIfEnabled(_ t: Track) {
        guard settings.lastfmScrobble, !settings.lastfmSessionKey.isEmpty else { return }
        Task { try? await LastFmClient.updateNowPlaying(track: t, settings: settings) }
    }

    @ViewBuilder
    private func historyThumb(_ item: HistoryItem) -> some View {
        if let d = item.artworkData, let img = UIImage(data: d) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
        }
    }

    private func deleteHistoryItem(_ item: HistoryItem) {
        var h = settings.history
        h.removeAll { $0.date == item.date && $0.track == item.track }
        settings.history = h
        history = h
    }

    private func clearHistory() {
        settings.history = []
        history = []
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
        settings.addHistory(track: t, text: composed.text, artworkData: artData)
        history = settings.history
        sendNowPlayingIfEnabled(t)
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
