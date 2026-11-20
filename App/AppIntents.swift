import AppIntents
import WidgetKit

/// Fetches the current track in the background (no app UI), updates the
/// widget and the history, and returns the composed post text. Usable
/// from Shortcuts, Back Tap, the Action button, and Siri.
struct FetchNowPlayingIntent: AppIntent {
    static var title: LocalizedStringResource = "Fetch Now Playing"
    static var description = IntentDescription("Fetches the current track and returns the composed post text.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let settings = NPSettings()
        guard let resolved = await Resolver.resolveDetailed(settings: settings) else {
            return .result(value: "", dialog: "Nothing is playing")
        }
        let (match, _) = await ITunesMatcher.search(track: resolved.track, quality: settings.artworkQuality)
        let composed = Composer.compose(track: resolved.track, itunes: match, settings: settings)
        settings.cachedTrack = resolved.track
        settings.addHistory(track: resolved.track, text: composed.text)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(value: composed.text, dialog: "\(composed.text)")
    }
}

struct NowPlayingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: FetchNowPlayingIntent(),
                    phrases: [
                        "Fetch now playing with \(.applicationName)",
                        "\(.applicationName)で今の曲を取得",
                    ],
                    shortTitle: "Fetch Now Playing",
                    systemImageName: "music.note")
        AppShortcut(intent: OpenNowPlayingIntent(),
                    phrases: [
                        "Open \(.applicationName)",
                        "\(.applicationName)を開く",
                    ],
                    shortTitle: "Open NowPlaying",
                    systemImageName: "play.circle")
    }
}
