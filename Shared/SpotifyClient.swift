import Foundation
import UIKit

public struct SpotifyState {
    public var track: Track
    public var isPlaying: Bool
    public var deviceName: String?
    public var deviceIsActive: Bool
    public var deviceType: String?

    /// Whether this state comes from the device the app is running on.
    /// Spotify names the active phone by the device's own name; fall back
    /// to the active Smartphone when the name doesn't match, so a paused
    /// track on another device can't win over playback here.
    public var isThisDevice: Bool {
        if let name = deviceName, !name.isEmpty,
           name == UIDevice.current.name { return true }
        return deviceIsActive && deviceType == "Smartphone"
    }
}

public enum SpotifyError: Error {
    case notConfigured
    case http(Int)
    case noItem
    case decode
}

public final class SpotifyClient {
    private let settings: NPSettings

    public init(settings: NPSettings) {
        self.settings = settings
    }

    /// GET /v1/me/player — account-wide playback state, with device info.
    public func fetchPlayer() async throws -> SpotifyState {
        let token = try await accessToken()
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw SpotifyError.http(code) }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let item = obj["item"] as? [String: Any],
              let name = item["name"] as? String else {
            throw SpotifyError.noItem
        }
        let artists = (item["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        let album = (item["album"] as? [String: Any])?["name"] as? String ?? ""
        let url = (item["external_urls"] as? [String: Any])?["spotify"] as? String
        let deviceObj = obj["device"] as? [String: Any]
        let device = deviceObj?["name"] as? String
        let deviceActive = deviceObj?["is_active"] as? Bool ?? false
        let deviceType = deviceObj?["type"] as? String
        let playing = obj["is_playing"] as? Bool ?? false
        let track = Track(title: name,
                          artistsJoined: artists.joined(separator: ", "),
                          artistFirst: artists.first ?? "",
                          album: album,
                          source: "spotify",
                          spotifyURL: url)
        return SpotifyState(track: track, isPlaying: playing, deviceName: device,
                            deviceIsActive: deviceActive, deviceType: deviceType)
    }

    private func accessToken() async throws -> String {
        let rt = settings.refreshToken
        guard !rt.isEmpty, !settings.clientSecret.isEmpty else {
            throw SpotifyError.notConfigured
        }
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var comps = URLComponents()
        comps.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: rt),
            URLQueryItem(name: "client_id", value: settings.clientID),
            URLQueryItem(name: "client_secret", value: settings.clientSecret),
        ]
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw SpotifyError.http(code) }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let at = obj["access_token"] as? String else {
            throw SpotifyError.decode
        }
        // Spotify may rotate the refresh token; keep the newest one.
        if let newRT = obj["refresh_token"] as? String, !newRT.isEmpty {
            settings.refreshToken = newRT
        }
        return at
    }
}
