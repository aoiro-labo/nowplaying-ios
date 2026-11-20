import Foundation

/// Settings shared between the app and the widget through an App Group.
/// User settings, shared between the app and the widget via App Group.
public final class NPSettings {
    public static let groupID = "group.jp.aoiro.nowplaying"
    public static let defaultClientID = ""
    public static let defaultFormat = "#NowPlaying {track} - {artist} ({album})"

    private let d: UserDefaults

    public init() {
        d = UserDefaults(suiteName: NPSettings.groupID) ?? .standard
    }

    private func str(_ key: String, _ def: String) -> String {
        let v = d.string(forKey: key)
        return (v == nil || v!.isEmpty) ? def : v!
    }

    public var refreshToken: String {
        get { str("refreshToken", "") }
        set { d.set(newValue, forKey: "refreshToken") }
    }
    public var clientSecret: String {
        get { str("clientSecret", "") }
        set { d.set(newValue, forKey: "clientSecret") }
    }
    public var clientID: String {
        get { str("clientID", NPSettings.defaultClientID) }
        set { d.set(newValue, forKey: "clientID") }
    }
    /// spotify / applemusic / auto
    public var source: String {
        get { str("source", "auto") }
        set { d.set(newValue, forKey: "source") }
    }
    /// off / space / newline
    public var urlMode: String {
        get { str("urlMode", "off") }
        set { d.set(newValue, forKey: "urlMode") }
    }
    public var artworkEnabled: Bool {
        get { d.object(forKey: "artwork") == nil ? true : d.bool(forKey: "artwork") }
        set { d.set(newValue, forKey: "artwork") }
    }
    /// default / high
    public var artworkQuality: String {
        get { str("artworkQuality", "default") }
        set { d.set(newValue, forKey: "artworkQuality") }
    }
    public var format: String {
        get { str("format", NPSettings.defaultFormat) }
        set { d.set(newValue, forKey: "format") }
    }

    // Posting destinations
    public var xConsumerKey: String {
        get { str("xConsumerKey", "") }
        set { d.set(newValue, forKey: "xConsumerKey") }
    }
    public var xConsumerSecret: String {
        get { str("xConsumerSecret", "") }
        set { d.set(newValue, forKey: "xConsumerSecret") }
    }
    public var xAccessToken: String {
        get { str("xAccessToken", "") }
        set { d.set(newValue, forKey: "xAccessToken") }
    }
    public var xAccessTokenSecret: String {
        get { str("xAccessTokenSecret", "") }
        set { d.set(newValue, forKey: "xAccessTokenSecret") }
    }
    public var bskyHandle: String {
        get { str("bskyHandle", "") }
        set { d.set(newValue, forKey: "bskyHandle") }
    }
    public var bskyAppPassword: String {
        get { str("bskyAppPassword", "") }
        set { d.set(newValue, forKey: "bskyAppPassword") }
    }
    public var bskyServer: String {
        get { str("bskyServer", "bsky.social") }
        set { d.set(newValue, forKey: "bskyServer") }
    }
    public var mastodonInstance: String {
        get { str("mastodonInstance", "") }
        set { d.set(newValue, forKey: "mastodonInstance") }
    }
    public var mastodonToken: String {
        get { str("mastodonToken", "") }
        set { d.set(newValue, forKey: "mastodonToken") }
    }
    public var misskeyInstance: String {
        get { str("misskeyInstance", "") }
        set { d.set(newValue, forKey: "misskeyInstance") }
    }
    public var misskeyToken: String {
        get { str("misskeyToken", "") }
        set { d.set(newValue, forKey: "misskeyToken") }
    }

    /// Saved format templates the user can switch between.
    public var formatPresets: [String] {
        get {
            guard let data = d.data(forKey: "formatPresets"),
                  let arr = try? JSONDecoder().decode([String].self, from: data),
                  !arr.isEmpty else { return [NPSettings.defaultFormat] }
            return arr
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                d.set(data, forKey: "formatPresets")
            }
        }
    }

    /// Recently fetched tracks with their composed post text, newest first.
    public var history: [HistoryItem] {
        get {
            guard let data = d.data(forKey: "history") else { return [] }
            return (try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                d.set(data, forKey: "history")
            }
        }
    }

    public func addHistory(track: Track, text: String) {
        var h = history
        if let first = h.first, first.track == track, first.text == text { return }
        h.insert(HistoryItem(track: track, text: text, date: Date()), at: 0)
        history = Array(h.prefix(20))
    }

    /// Last resolved track, written by the app, read by the widget as a fallback.
    public var cachedTrack: Track? {
        get {
            guard let data = d.data(forKey: "cachedTrack") else { return nil }
            return try? JSONDecoder().decode(Track.self, from: data)
        }
        set {
            if let t = newValue, let data = try? JSONEncoder().encode(t) {
                d.set(data, forKey: "cachedTrack")
            }
        }
    }
}
