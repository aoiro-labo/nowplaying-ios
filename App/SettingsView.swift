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

    var body: some View {
        NavigationStack {
            Form {
                Section("Spotify") {
                    TextField("refresh_token", text: $refreshToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Client Secret", text: $clientSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Client ID", text: $clientID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("「NowPlaying Config」メモの内容をそのまま貼れば OK。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("取得元 (source)") {
                    Picker("source", selection: $source) {
                        Text("auto（この端末優先）").tag("auto")
                        Text("Spotify").tag("spotify")
                        Text("Apple Music").tag("applemusic")
                    }.pickerStyle(.inline).labelsHidden()
                }
                Section("URL の付け方 (url)") {
                    Picker("url", selection: $urlMode) {
                        Text("付けない").tag("off")
                        Text("スペース区切り").tag("space")
                        Text("改行").tag("newline")
                    }.pickerStyle(.inline).labelsHidden()
                    Text("format に {url} が含まれている場合はそちらが優先。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("ジャケ写") {
                    Toggle("ジャケ写を付ける", isOn: $artwork)
                    Picker("画質", selection: $artworkQuality) {
                        Text("標準").tag("default")
                        Text("高画質 (1200px)").tag("high")
                    }
                }
                Section("文面 (format)") {
                    TextField("{track} {artist} {album} {url}", text: $format, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { save(); dismiss() }
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
