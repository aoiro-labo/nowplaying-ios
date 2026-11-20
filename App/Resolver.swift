import Foundation

/// Source resolution, mirroring the shortcut's "auto" cascade:
/// in auto mode a healthy Apple Music reading wins (it reflects what
/// this device is playing now); otherwise Spotify's account state is
/// used when it has an item at all.
public enum Resolver {
    public static func resolve(settings: NPSettings) async -> Track? {
        switch settings.source {
        case "spotify":
            return try? await SpotifyClient(settings: settings).fetchPlayer().track
        case "applemusic":
            return AppleMusicClient.currentTrack()
        default:
            if let am = AppleMusicClient.currentTrack() { return am }
            if let st = try? await SpotifyClient(settings: settings).fetchPlayer() {
                return st.track
            }
            return nil
        }
    }
}
