import Foundation
import CryptoKit

/// Last.fm integration:
/// - Read: `user.getrecenttracks` (username + API key only) as a source.
/// - Write: signed calls with a session key — `track.updateNowPlaying`
///   and `track.scrobble`. The session comes from the standard web auth
///   flow (auth.gettoken -> user authorizes in the browser ->
///   auth.getsession).
public enum LastFmError: Error {
    case notConfigured
    case http(Int)
    case api(String)
    case decode
}

public enum LastFmClient {
    private static let base = "https://ws.audioscrobbler.com/2.0/"

    // MARK: - Read

    /// Latest track for the user, with its now-playing flag.
    public static func fetchRecent(username: String, apiKey: String) async throws -> (track: Track, isPlaying: Bool) {
        guard !username.isEmpty, !apiKey.isEmpty else { throw LastFmError.notConfigured }
        var comps = URLComponents(string: base)!
        comps.queryItems = [
            URLQueryItem(name: "method", value: "user.getrecenttracks"),
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "format", value: "json"),
        ]
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        if let h = resp as? HTTPURLResponse, h.statusCode != 200 { throw LastFmError.http(h.statusCode) }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let recent = root["recenttracks"] as? [String: Any] else { throw LastFmError.decode }
        var first: [String: Any]?
        if let arr = recent["track"] as? [[String: Any]] { first = arr.first }
        if let obj = recent["track"] as? [String: Any] { first = obj }
        guard let t = first,
              let name = t["name"] as? String, !name.isEmpty else { throw LastFmError.decode }
        let artist = (t["artist"] as? [String: Any])?["#text"] as? String ?? ""
        let album = (t["album"] as? [String: Any])?["#text"] as? String ?? ""
        let url = t["url"] as? String ?? ""
        let nowPlaying = ((t["@attr"] as? [String: Any])?["nowplaying"] as? String) == "true"
        let track = Track(title: name, artists: [artist], album: album, url: url, source: "lastfm")
        return (track, nowPlaying)
    }

    // MARK: - Auth

    public static func getToken(apiKey: String, apiSecret: String) async throws -> String {
        let json = try await signedGET(["method": "auth.gettoken", "api_key": apiKey], secret: apiSecret)
        guard let token = json["token"] as? String else { throw LastFmError.decode }
        return token
    }

    public static func authURL(apiKey: String, token: String) -> URL {
        URL(string: "https://www.last.fm/api/auth/?api_key=\(apiKey)&token=\(token)")!
    }

    public static func getSession(token: String, apiKey: String, apiSecret: String) async throws -> (username: String, key: String) {
        let json = try await signedGET(["method": "auth.getsession", "api_key": apiKey, "token": token],
                                       secret: apiSecret)
        guard let s = json["session"] as? [String: Any],
              let name = s["name"] as? String, let key = s["key"] as? String else { throw LastFmError.decode }
        return (name, key)
    }

    // MARK: - Write

    public static func updateNowPlaying(track: Track, settings: NPSettings) async throws {
        try await signedPOST([
            "method": "track.updatenowplaying",
            "api_key": settings.lastfmAPIKey,
            "sk": settings.lastfmSessionKey,
            "track": track.title,
            "artist": track.artistsJoined,
            "album": track.album,
        ], secret: settings.lastfmAPISecret)
    }

    public static func scrobble(track: Track, timestamp: Date, settings: NPSettings) async throws {
        try await signedPOST([
            "method": "track.scrobble",
            "api_key": settings.lastfmAPIKey,
            "sk": settings.lastfmSessionKey,
            "track": track.title,
            "artist": track.artistsJoined,
            "album": track.album,
            "timestamp": String(Int(timestamp.timeIntervalSince1970)),
        ], secret: settings.lastfmAPISecret)
    }

    // MARK: - Signing plumbing

    /// api_sig: MD5 of the parameters (sorted by name, name+value
    /// concatenated, format/callback excluded) plus the shared secret.
    private static func signature(_ params: [String: String], secret: String) -> String {
        var s = ""
        for key in params.keys.sorted() where key != "format" && key != "callback" {
            s += key + (params[key] ?? "")
        }
        s += secret
        let digest = Insecure.MD5.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func signedGET(_ params: [String: String], secret: String) async throws -> [String: Any] {
        var p = params
        p["api_sig"] = signature(p, secret: secret)
        p["format"] = "json"
        var comps = URLComponents(string: base)!
        comps.queryItems = p.map { URLQueryItem(name: $0.key, value: $0.value) }
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        if let h = resp as? HTTPURLResponse, h.statusCode != 200 { throw LastFmError.http(h.statusCode) }
        return try parse(data)
    }

    @discardableResult
    private static func signedPOST(_ params: [String: String], secret: String) async throws -> [String: Any] {
        guard !secret.isEmpty else { throw LastFmError.notConfigured }
        var p = params
        p["api_sig"] = signature(p, secret: secret)
        p["format"] = "json"
        var req = URLRequest(url: URL(string: base)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = p.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")" }
            .joined(separator: "&").data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let h = resp as? HTTPURLResponse, h.statusCode != 200 { throw LastFmError.http(h.statusCode) }
        return try parse(data)
    }

    private static func parse(_ data: Data) throws -> [String: Any] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LastFmError.decode
        }
        if let msg = root["message"] as? String, root["error"] != nil {
            throw LastFmError.api(msg)
        }
        return root
    }
}
