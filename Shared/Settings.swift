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
