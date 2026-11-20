import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    private let settings = NPSettings()

    @State private var refreshToken: String = ""
    @State private var clientSecret: String = ""
    @State private var clientID: String = ""
    @State private var source: String = "auto"
    @State private var urlMode: String = "off"
    @State private var artwork: Bool = true
    @State private var artworkQuality: String = "default"
    @State private var format: String = ""
    @State private var xConsumerKey: String = ""
    @State private var xConsumerSecret: String = ""
    @State private var xAccessToken: String = ""
    @State private var xAccessTokenSecret: String = ""
    @State private var bskyHandle: String = ""
    @State private var bskyAppPassword: String = ""
    @State private var bskyServer: String = "bsky.social"
    @State private var mastodonInstance: String = ""
    @State private var mastodonToken: String = ""
    @State private var misskeyInstance: String = ""
    @State private var misskeyToken: String = ""
    @State private var presets: [String] = []
    @State private var lastfmUsername: String = ""
    @State private var lastfmAPIKey: String = ""
    @State private var lastfmAPISecret: String = ""
    @State private var lastfmSessionKey: String = ""
    @State private var lastfmScrobble: Bool = false
    @State private var pendingToken: String = ""
    @State private var lfmMessage: String = ""
    @State private var showProbe = false

    var body: some View {
        NavigationStack {
            Form {
                spotifySection
                sourceSection
                urlSection
                artworkSection
                formatSection
                xSection
                blueskySection
                mastodonSection
                misskeySection
                lastfmSection
                diagnosticsSection
                aboutSection
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showProbe) {
                MediaRemoteProbeView()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { save(); dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Close") { dismissKeyboard() }
                }
            }
            .onAppear(perform: load)
        }
    }

    // MARK: - Section helpers

    /// Section header: icon + title, plus a configured/not-configured
    /// status on the right when `configured` is given.
    private func header(_ title: LocalizedStringKey, icon: String, configured: Bool? = nil) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if let configured {
                Text(configured ? "Configured" : "Not configured")
                    .font(.caption2).bold()
                    .foregroundStyle(configured ? .green : .secondary)
                    .textCase(nil)
            }
        }
    }

    /// Labeled credential row: the label stays visible even when the
    /// field is filled, so long tokens remain identifiable.
    private func fieldRow(_ label: LocalizedStringKey, text: Binding<String>,
                          secure: Bool = false, prompt: String? = nil) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 104, alignment: .leading)
            Group {
                if secure {
                    SecureField("", text: text, prompt: prompt.map { Text($0) })
                } else {
                    TextField("", text: text, prompt: prompt.map { Text($0) })
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
    }

    // MARK: - Sections

    private var spotifySection: some View {
        Section {
            fieldRow("Refresh token", text: $refreshToken)
            fieldRow("Client Secret", text: $clientSecret, secure: true)
            fieldRow("Client ID", text: $clientID)
        } header: {
            header("Spotify", icon: "music.note",
                   configured: !refreshToken.isEmpty && !clientSecret.isEmpty && !clientID.isEmpty)
        } footer: {
            Text("Create an app at developer.spotify.com, register the redirect URI http://127.0.0.1:8888/callback, and paste the credentials of your app here. See the README for how to get a refresh token.")
        }
    }

    private var sourceSection: some View {
        Section {
            Picker("Source", selection: $source) {
                Text("Auto (this device first)").tag("auto")
                Text("Spotify").tag("spotify")
                Text("Apple Music").tag("applemusic")
                Text("Last.fm").tag("lastfm")
            }.pickerStyle(.inline).labelsHidden()
        } header: {
            header("Source", icon: "arrow.triangle.2.circlepath")
        }
    }

    private var urlSection: some View {
        Section {
            Picker("URL", selection: $urlMode) {
                Text("Off").tag("off")
                Text("Space-separated").tag("space")
                Text("New line").tag("newline")
            }.pickerStyle(.inline).labelsHidden()
        } header: {
            header("URL", icon: "link")
        } footer: {
            Text("If the format contains {url}, that takes precedence.")
        }
    }

    private var artworkSection: some View {
        Section {
            Toggle("Attach artwork", isOn: $artwork)
            Picker("Quality", selection: $artworkQuality) {
                Text("Standard").tag("default")
                Text("High (1200px)").tag("high")
            }
        } header: {
            header("Artwork", icon: "photo")
        }
    }

    private var formatSection: some View {
        Section {
            TextField("{track} {artist} {album} {url}", text: $format, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: format) { old, new in
                    // Editing and switching share one list: when the field
                    // is edited, the preset it came from follows the edit,
                    // so the two never diverge or duplicate.
                    if let idx = presets.firstIndex(of: old), !presets.contains(new) {
                        presets[idx] = new
                    }
                }
            if !presets.isEmpty {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        format = preset
                    } label: {
                        HStack {
                            Text(preset)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                            Spacer()
                            if preset == format {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
                .onDelete { presets.remove(atOffsets: $0) }
            }
            if !presets.contains(format) {
                Button("Add current format as preset") {
                    let f = format.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !f.isEmpty { presets.append(f) }
                }
            }
        } header: {
            header("Format", icon: "text.quote")
        } footer: {
            Text("Tap a preset to switch. Editing the field updates the selected preset. Swipe to delete.")
        }
    }

    private var xSection: some View {
        Section {
            fieldRow("API Key", text: $xConsumerKey)
            fieldRow("API Secret", text: $xConsumerSecret, secure: true)
            fieldRow("Access Token", text: $xAccessToken)
            fieldRow("Access Token Secret", text: $xAccessTokenSecret, secure: true)
        } header: {
            header("X API", icon: "paperplane",
                   configured: !xConsumerKey.isEmpty && !xConsumerSecret.isEmpty
                       && !xAccessToken.isEmpty && !xAccessTokenSecret.isEmpty)
        } footer: {
            Text("Create an app at developer.x.com, set its permissions to Read and Write, then generate the access token for your account. Generate the token after setting Write permission, otherwise posting fails.")
        }
    }

    private var blueskySection: some View {
        Section {
            fieldRow("Handle", text: $bskyHandle, prompt: "you.bsky.social")
            fieldRow("App password", text: $bskyAppPassword, secure: true)
            fieldRow("Server", text: $bskyServer)
        } header: {
            header("Bluesky", icon: "cloud",
                   configured: !bskyHandle.isEmpty && !bskyAppPassword.isEmpty)
        } footer: {
            Text("Use an app password from Bluesky settings, not your main password.")
        }
    }

    private var mastodonSection: some View {
        Section {
            fieldRow("Instance", text: $mastodonInstance, prompt: "mstdn.jp")
            fieldRow("Access Token", text: $mastodonToken, secure: true)
        } header: {
            header("Mastodon", icon: "message",
                   configured: !mastodonInstance.isEmpty && !mastodonToken.isEmpty)
        } footer: {
            Text("Create a token on your instance under Preferences, Development, New application (scopes: write:statuses and write:media).")
        }
    }

    private var misskeySection: some View {
        Section {
            fieldRow("Instance", text: $misskeyInstance, prompt: "misskey.io")
            fieldRow("API Token", text: $misskeyToken, secure: true)
        } header: {
            header("Misskey", icon: "star",
                   configured: !misskeyInstance.isEmpty && !misskeyToken.isEmpty)
        } footer: {
            Text("Create an API token on your instance under Settings, API.")
        }
    }

    private var lastfmSection: some View {
        Section {
            fieldRow("Username", text: $lastfmUsername)
            fieldRow("API Key", text: $lastfmAPIKey)
            fieldRow("API Secret", text: $lastfmAPISecret, secure: true)
            if lastfmSessionKey.isEmpty {
                Button("Connect Last.fm") { Task { await connectLastFm() } }
                if !pendingToken.isEmpty {
                    Button("Finish connection") { Task { await finishLastFm() } }
                }
            } else {
                HStack {
                    Text("Connected")
                    Spacer()
                    Text(lastfmUsername).foregroundStyle(.secondary)
                }
                Button("Disconnect", role: .destructive) { disconnectLastFm() }
            }
            Toggle("Scrobble integration", isOn: $lastfmScrobble)
            if !lfmMessage.isEmpty {
                Text(lfmMessage).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            header("Last.fm", icon: "waveform")
        } footer: {
            Text("Using Last.fm as a source needs only the username and API key. Scrobbling needs the connection: Connect opens last.fm in the browser; approve there, come back, and tap Finish connection. When the integration is on, fetching sends Now Playing and posting scrobbles.")
        }
    }

    private var diagnosticsSection: some View {
        Section {
            Button("MediaRemote probe") { showProbe = true }
        } header: {
            header("Diagnostics", icon: "stethoscope")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion).foregroundStyle(.secondary)
            }
            Link(destination: URL(string: "https://github.com/aoiro-labo/nowplaying-app")!) {
                HStack {
                    Text("GitHub")
                    Spacer()
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundStyle(.secondary)
                }
            }
            Link(destination: feedbackURL) {
                HStack {
                    Text("Report a problem")
                    Spacer()
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            header("About", icon: "info.circle")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var feedbackURL: URL {
        var comps = URLComponents(string: "https://github.com/aoiro-labo/nowplaying-app/issues/new")!
        comps.queryItems = [
            URLQueryItem(name: "title", value: "[フィードバック] "),
            URLQueryItem(name: "body", value: "## 内容\n\n\n## アプリ\n- バージョン: \(appVersion)\n"),
        ]
        return comps.url!
    }

    // MARK: - Last.fm connect flow

    private func connectLastFm() async {
        lfmMessage = ""
        do {
            let token = try await LastFmClient.getToken(
                apiKey: lastfmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
                apiSecret: lastfmAPISecret.trimmingCharacters(in: .whitespacesAndNewlines))
            pendingToken = token
            openURL(LastFmClient.authURL(
                apiKey: lastfmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
                token: token))
            lfmMessage = NSLocalizedString("Approve in the browser, then tap Finish connection.", comment: "")
        } catch {
            lfmMessage = error.localizedDescription
        }
    }

    private func finishLastFm() async {
        lfmMessage = ""
        do {
            let s = try await LastFmClient.getSession(
                token: pendingToken,
                apiKey: lastfmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
                apiSecret: lastfmAPISecret.trimmingCharacters(in: .whitespacesAndNewlines))
            settings.lastfmSessionKey = s.key
            settings.lastfmUsername = s.username
            lastfmSessionKey = s.key
            lastfmUsername = s.username
            pendingToken = ""
        } catch {
            lfmMessage = error.localizedDescription
        }
    }

    private func disconnectLastFm() {
        settings.lastfmSessionKey = ""
        lastfmSessionKey = ""
        pendingToken = ""
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    // MARK: - Load / save

    private func load() {
        refreshToken = settings.refreshToken
        clientSecret = settings.clientSecret
        clientID = settings.clientID
        source = settings.source
        urlMode = settings.urlMode
        artwork = settings.artworkEnabled
        artworkQuality = settings.artworkQuality
        format = settings.format
        xConsumerKey = settings.xConsumerKey
        xConsumerSecret = settings.xConsumerSecret
        xAccessToken = settings.xAccessToken
        xAccessTokenSecret = settings.xAccessTokenSecret
        bskyHandle = settings.bskyHandle
        bskyAppPassword = settings.bskyAppPassword
        bskyServer = settings.bskyServer
        mastodonInstance = settings.mastodonInstance
        mastodonToken = settings.mastodonToken
        misskeyInstance = settings.misskeyInstance
        misskeyToken = settings.misskeyToken
        presets = settings.formatPresets
        lastfmUsername = settings.lastfmUsername
        lastfmAPIKey = settings.lastfmAPIKey
        lastfmAPISecret = settings.lastfmAPISecret
        lastfmSessionKey = settings.lastfmSessionKey
        lastfmScrobble = settings.lastfmScrobble
    }

    private func save() {
        settings.refreshToken = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.clientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.source = source
        settings.urlMode = urlMode
        settings.artworkEnabled = artwork
        settings.artworkQuality = artworkQuality
        settings.format = format
        settings.xConsumerKey = xConsumerKey.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.xConsumerSecret = xConsumerSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.xAccessToken = xAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.xAccessTokenSecret = xAccessTokenSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.bskyHandle = bskyHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.bskyAppPassword = bskyAppPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.bskyServer = bskyServer.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.mastodonInstance = mastodonInstance.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.mastodonToken = mastodonToken.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.misskeyInstance = misskeyInstance.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.misskeyToken = misskeyToken.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.formatPresets = presets
        settings.lastfmUsername = lastfmUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.lastfmAPIKey = lastfmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.lastfmAPISecret = lastfmAPISecret.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.lastfmScrobble = lastfmScrobble
    }
}
