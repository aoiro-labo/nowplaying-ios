import SwiftUI
import UIKit
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
    @State private var autoMatch: ITunesMatch?
    @State private var autoArtData: Data?
    @State private var candidates: [ITunesCandidate] = []
    @State private var mbCandidates: [MBCandidate] = []
    @State private var sourceArtworkData: Data?
    @State private var manualPick: ArtworkPick = .auto
    @State private var showArtworkPicker = false
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
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                actionsRow
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .background(.bar)
            }
            .navigationTitle("NowPlaying")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Close") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                }
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(items: shareItems())
            }
            .sheet(isPresented: $showSettings, onDismiss: { history = settings.history }) {
                SettingsView()
            }
            .sheet(isPresented: $showArtworkPicker) {
                ArtworkPickerView(
                    candidates: candidates,
                    mbCandidates: mbCandidates,
                    autoMatch: autoMatch,
                    sourceArtworkData: sourceArtworkData,
                    sourceName: track.map { sourceName($0.source) } ?? "",
                    initial: manualPick,
                    onApply: { pick in Task { await applyPick(pick) } },
                    onReport: { pick in openURL(artworkReportURL(correctPick: pick)) })
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
                    .contextMenu {
                        if !candidates.isEmpty || !mbCandidates.isEmpty || sourceArtworkData != nil {
                            Button("Choose artwork") { showArtworkPicker = true }
                        }
                        Button("Report wrong artwork") { openURL(artworkReportURL()) }
                    }
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

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    /// Prefilled GitHub issue for a wrong artwork pick: the track, the
    /// auto-chosen iTunes result, the correct one when the user picked
    /// it by hand, and the full candidate list for reproduction.
    private func artworkReportURL(correctPick: ArtworkPick? = nil) -> URL {
        let t = track
        let pick = correctPick ?? manualPick
        var correct = "（未選択）"
        switch pick {
        case .candidate(let i) where candidates.indices.contains(i):
            let c = candidates[i]
            correct = """
            - コレクション: \(c.collectionName)
            - trackViewUrl: \(c.trackViewURL)
            - artworkUrl100: \(c.artworkURL100)
            """
        case .musicbrainz(let i) where mbCandidates.indices.contains(i):
            let c = mbCandidates[i]
            correct = """
            MusicBrainz のリリース
            - リリース: \(c.releaseTitle)
            - \(c.pageURL)
            - ジャケ写: \(c.artworkURL)
            """
        case .source:
            correct = "再生元サービス（\(t.map { sourceName($0.source) } ?? "")）のジャケ写"
        default:
            break
        }
        let candidateList = candidates.enumerated().map {
            "\($0.offset + 1). \($0.element.collectionName) — \($0.element.trackViewURL)"
        }.joined(separator: "\n")
        let body = """
        ## 種別
        ジャケ写の選択ミス

        ## 曲
        - タイトル: \(t?.title ?? "")
        - アーティスト: \(t?.artistsJoined ?? "")
        - アルバム: \(t?.album ?? "")
        - 取得元: \(t?.source ?? "")

        ## 自動で選ばれた iTunes 結果
        - trackViewUrl: \(autoMatch?.trackViewURL ?? "-")
        - artworkUrl100: \(autoMatch?.artworkURL100 ?? "-")

        ## 正解として選ばれた結果
        \(correct)

        ## 候補一覧
        \(candidateList.isEmpty ? "（なし）" : candidateList)

        ## アプリ
        - バージョン: \(appVersion)
        """
        var comps = URLComponents(string: "https://github.com/aoiro-labo/nowplaying-app/issues/new")!
        comps.queryItems = [
            URLQueryItem(name: "title", value: "[ジャケ写] \(t?.title ?? "")"),
            URLQueryItem(name: "body", value: body),
        ]
        return comps.url!
    }

    /// Applies a manual artwork pick: swaps the effective iTunes match
    /// (which drives both the artwork and the post URL) and recomposes.
    private func applyPick(_ pick: ArtworkPick) async {
        manualPick = pick
        switch pick {
        case .auto:
            lastMatch = autoMatch
            artworkData = settings.artworkEnabled ? (autoArtData ?? sourceArtworkData) : nil
        case .candidate(let i):
            guard candidates.indices.contains(i) else { return }
            let c = candidates[i]
            lastMatch = c.match
            let d = await loadArtworkData(url100: c.artworkURL100)
            artworkData = settings.artworkEnabled ? (d ?? autoArtData ?? sourceArtworkData) : nil
        case .musicbrainz(let i):
            // MusicBrainz picks change only the artwork; the post URL
            // keeps coming from the iTunes match / source service.
            guard mbCandidates.indices.contains(i) else { return }
            let c = mbCandidates[i]
            let u = settings.artworkQuality == "high" ? c.artworkURLHigh : c.artworkURL
            if let url = URL(string: u),
               let (d, resp) = try? await URLSession.shared.data(from: url),
               (resp as? HTTPURLResponse)?.statusCode == 200 {
                artworkData = settings.artworkEnabled ? d : nil
            }
        case .source:
            lastMatch = nil
            artworkData = settings.artworkEnabled ? (sourceArtworkData ?? autoArtData) : nil
        }
        artwork = artworkData.flatMap { UIImage(data: $0) }
        if let t = track {
            postText = Composer.compose(track: t, itunes: lastMatch, settings: settings).text
        }
    }

    private func loadArtworkData(url100: String) async -> Data? {
        let high = settings.artworkQuality == "high"
        let wanted = high
            ? url100.replacingOccurrences(of: "100x100bb", with: "1200x1200bb")
            : url100
        if let u = URL(string: wanted), let (d, _) = try? await URLSession.shared.data(from: u) {
            return d
        }
        if high, let u = URL(string: url100),
           let (d, _) = try? await URLSession.shared.data(from: u) {
            return d
        }
        return nil
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
        let (match, artData, _) = await ITunesMatcher.search(track: item.track, quality: settings.artworkQuality)
        lastMatch = match
        autoMatch = match
        autoArtData = artData
        candidates = []
        mbCandidates = []
        sourceArtworkData = nil
        manualPick = .auto
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
        // The source service's own artwork: fallback when the iTunes
        // match has none, and a manual pick option.
        var srcData = resolved.sourceArtworkData
        if srcData == nil, let urlStr = resolved.sourceArtworkURL, let u = URL(string: urlStr),
           let (d, _) = try? await URLSession.shared.data(from: u) {
            srcData = d
        }
        sourceArtworkData = srcData
        let (match, artData, cands) = await ITunesMatcher.search(track: t, quality: settings.artworkQuality)
        let composed = Composer.compose(track: t, itunes: match, settings: settings)
        track = t
        isPlaying = resolved.isPlaying
        autoMatch = match
        autoArtData = artData
        candidates = cands
        mbCandidates = []
        manualPick = .auto
        lastMatch = match
        postText = composed.text
        artworkData = settings.artworkEnabled ? (artData ?? srcData) : nil
        artwork = artworkData.flatMap { UIImage(data: $0) }
        status = ""
        settings.cachedTrack = t
        settings.addHistory(track: t, text: composed.text, artworkData: artData)
        history = settings.history
        sendNowPlayingIfEnabled(t)
        WidgetCenter.shared.reloadAllTimelines()

        // MusicBrainz: extra artwork candidates, plus a fallback when
        // the iTunes match brought no artwork (before the source
        // service's own artwork, which is already in place above).
        guard settings.artworkEnabled else { return }
        let mbs = await MusicBrainzClient.searchReleases(track: t)
        guard track?.title == t.title, track?.album == t.album else { return }
        mbCandidates = mbs
        if artData == nil, manualPick == .auto {
            let albumN = ITunesMatcher.normalizeAlbum(t.album)
            if let hit = mbs.first(where: { ITunesMatcher.normalizeAlbum($0.releaseTitle) == albumN }) {
                let u = settings.artworkQuality == "high" ? hit.artworkURLHigh : hit.artworkURL
                if let url = URL(string: u),
                   let (d, resp) = try? await URLSession.shared.data(from: url),
                   (resp as? HTTPURLResponse)?.statusCode == 200,
                   track?.title == t.title {
                    artworkData = d
                    artwork = UIImage(data: d)
                }
            }
        }
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

/// Which artwork the user picked by hand: the automatic iTunes match,
/// one of the iTunes candidates, or the source service's own artwork.
enum ArtworkPick: Equatable {
    case auto
    case candidate(Int)
    case musicbrainz(Int)
    case source
}

/// Artwork candidate picker. Tapping a row selects it; Apply swaps the
/// artwork (and the post URL) to the selection, and "Report as correct"
/// opens a GitHub issue with the selection as the correct answer.
struct ArtworkPickerView: View {
    let candidates: [ITunesCandidate]
    let mbCandidates: [MBCandidate]
    let autoMatch: ITunesMatch?
    let sourceArtworkData: Data?
    let sourceName: String
    let initial: ArtworkPick
    let onApply: (ArtworkPick) -> Void
    let onReport: (ArtworkPick) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: ArtworkPick = .auto

    var body: some View {
        NavigationStack {
            List {
                Section {
                    autoRow
                    ForEach(candidates.indices, id: \.self) { i in
                        candidateRow(i)
                    }
                    if let d = sourceArtworkData, let img = UIImage(data: d) {
                        pickRow(selection: .source, thumb: .image(img),
                                title: NSLocalizedString("Source service artwork", comment: ""),
                                subtitle: sourceName)
                    }
                } header: {
                    Text("Artwork candidates")
                }
                if !mbCandidates.isEmpty {
                    Section {
                        ForEach(mbCandidates.indices, id: \.self) { i in
                            mbRow(i)
                        }
                    } header: {
                        Text("MusicBrainz")
                    }
                }
            }
            .navigationTitle("Choose artwork")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    if selection != .auto {
                        Button("Report as correct") {
                            onReport(selection)
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                    Button("Apply") {
                        onApply(selection)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(.bar)
            }
            .onAppear { selection = initial }
        }
    }

    private enum Thumb {
        case url(String)
        case image(UIImage)
        case none
    }

    private var autoCandidate: ITunesCandidate? {
        guard let m = autoMatch else { return nil }
        return candidates.first { $0.trackViewURL == m.trackViewURL }
    }

    private var autoRow: some View {
        pickRow(selection: .auto,
                thumb: autoCandidate.map { .url($0.artworkURL100) } ?? .none,
                title: NSLocalizedString("Auto-selected", comment: ""),
                subtitle: autoCandidate?.collectionName ?? "—")
    }

    private func candidateRow(_ i: Int) -> some View {
        let c = candidates[i]
        return pickRow(selection: .candidate(i),
                       thumb: .url(c.artworkURL100),
                       title: c.collectionName.isEmpty ? c.trackName : c.collectionName,
                       subtitle: "\(c.trackName) — \(c.artistName)")
    }

    private func mbRow(_ i: Int) -> some View {
        let c = mbCandidates[i]
        let sub = c.date.isEmpty ? c.artistName : "\(c.artistName) · \(c.date)"
        return pickRow(selection: .musicbrainz(i),
                       thumb: .url(c.artworkURL),
                       title: c.releaseTitle,
                       subtitle: sub)
    }

    private func pickRow(selection pick: ArtworkPick, thumb: Thumb,
                         title: String, subtitle: String) -> some View {
        Button {
            selection = pick
        } label: {
            HStack(spacing: 12) {
                thumbView(thumb)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).bold().lineLimit(1)
                    Text(subtitle).font(.caption)
                        .foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if selection == pick {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func thumbView(_ thumb: Thumb) -> some View {
        Group {
            switch thumb {
            case .url(let s):
                AsyncImage(url: URL(string: s)) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color.secondary.opacity(0.2)
                }
            case .image(let img):
                Image(uiImage: img).resizable().scaledToFill()
            case .none:
                Color.secondary.opacity(0.2)
                    .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
