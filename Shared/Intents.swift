import AppIntents

/// Opens the app. Shared between the app (Shortcuts) and the widget
/// extension (Control Center control on iOS 18+).
public struct OpenNowPlayingIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open NowPlaying"
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        .result()
    }
}
