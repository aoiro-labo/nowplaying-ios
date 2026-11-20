import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
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
    @State private var showProbe = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Spotify") {
                    TextField("Refresh token", text: $refreshToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Client Secret", text: $clientSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Client ID", text: $clientID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Create an app at developer.spotify.com, register the redirect URI http://127.0.0.1:8888/callback, and paste the credentials of your app here. See the README for how to get a refresh token.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Source") {
                    Picker("Source", selection: $source) {
                        Text("Auto (this device first)").tag("auto")
                        Text("Spotify").tag("spotify")
                        Text("Apple Music").tag("applemusic")
                    }.pickerStyle(.inline).labelsHidden()
                }
                Section("URL") {
                    Picker("URL", selection: $urlMode) {
                        Text("Off").tag("off")
                        Text("Space-separated").tag("space")
                        Text("New line").tag("newline")
                    }.pickerStyle(.inline).labelsHidden()
                    Text("If the format contains {url}, that takes precedence.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Artwork") {
                    Toggle("Attach artwork", isOn: $artwork)
                    Picker("Quality", selection: $artworkQuality) {
                        Text("Standard").tag("default")
                        Text("High (1200px)").tag("high")
                    }
                }
                Section("Format") {
                    TextField("{track} {artist} {album} {url}", text: $format, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("X API") {
                    TextField("API Key", text: $xConsumerKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API Secret", text: $xConsumerSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Access Token", text: $xAccessToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Access Token Secret", text: $xAccessTokenSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Create an app at developer.x.com, set its permissions to Read and Write, then generate the access token for your account. Generate the token after setting Write permission, otherwise posting fails.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Bluesky") {
                    TextField("Handle (e.g. you.bsky.social)", text: $bskyHandle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("App password", text: $bskyAppPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Server", text: $bskyServer)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Use an app password from Bluesky settings, not your main password.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Mastodon") {
                    TextField("Instance (e.g. mstdn.jp)", text: $mastodonInstance)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Access Token", text: $mastodonToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Create a token on your instance under Preferences, Development, New application (scopes: write:statuses and write:media).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Misskey") {
                    TextField("Instance (e.g. misskey.io)", text: $misskeyInstance)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API Token", text: $misskeyToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Create an API token on your instance under Settings, API.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Diagnostics") {
                    Button("MediaRemote probe") { showProbe = true }
                }
            }
            .sheet(isPresented: $showProbe) {
                MediaRemoteProbeView()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { save(); dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

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
    }
}
