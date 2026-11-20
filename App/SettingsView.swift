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
    }
}
