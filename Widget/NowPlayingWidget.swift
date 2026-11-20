import WidgetKit
import SwiftUI
import UIKit
import AppIntents

struct NPEntry: TimelineEntry {
    let date: Date
    let track: Track?
    let artworkData: Data?
}

struct ConfigureIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "NowPlaying"
}

struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh"
    static var description = IntentDescription("Reload the current track.")
    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NPEntry {
        NPEntry(date: Date(), track: nil, artworkData: nil)
    }

    func snapshot(for configuration: ConfigureIntent, in context: Context) async -> NPEntry {
        await load()
    }

    func timeline(for configuration: ConfigureIntent, in context: Context) async -> Timeline<NPEntry> {
        let entry = await load()
        return Timeline(entries: [entry],
                        policy: .after(Date().addingTimeInterval(1800)))
    }

    private func load() async -> NPEntry {
        let settings = NPSettings()
        var track: Track? = nil
        if !settings.refreshToken.isEmpty {
            track = try? await SpotifyClient(settings: settings).fetchPlayer().track
        }
        if track == nil {
            track = settings.cachedTrack
        }
        var art: Data? = nil
        if let t = track {
            art = await ITunesMatcher.search(track: t, quality: "default").artworkData
        }
        return NPEntry(date: Date(), track: track, artworkData: art)
    }
}

struct NPWidgetView: View {
    var entry: NPEntry

    var body: some View {
        Group {
            if let t = entry.track {
                HStack(spacing: 10) {
                    if let d = entry.artworkData, let img = UIImage(data: d) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .cornerRadius(8)
                            .clipped()
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t.title)
                            .font(.subheadline).bold().lineLimit(2)
                        Text(t.artistsJoined)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Button(intent: RefreshIntent()) {
                            Image(systemName: "arrow.clockwise").font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            } else {
                VStack(spacing: 6) {
                    Text("NowPlaying").font(.subheadline).bold()
                    Text("曲が取得できていません")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(intent: RefreshIntent()) {
                        Label("更新", systemImage: "arrow.clockwise").font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "nowplaying://open"))
    }
}

struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "NowPlayingWidget",
                               intent: ConfigureIntent.self,
                               provider: Provider()) { entry in
            NPWidgetView(entry: entry)
        }
        .configurationDisplayName("NowPlaying")
        .description("再生中の曲を表示します。タップでアプリを開きます。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct NPWidgets: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
    }
}
