import Foundation

/// Source resolution. "auto" means: prefer what is actually playing
/// on THIS device. The Music app's now-playing item can be a stale
/// paused track, so Apple only wins outright while it is really
/// playing; otherwise Spotify's state (which knows whether something
/// is playing, and what) beats a leftover Music item.
public enum Resolver {
    public static func resolve(settings: NPSettings) async -> Track? {
        switch settings.source {
        case "spotify":
            return try? await SpotifyClient(settings: settings).fetchPlayer().track
        case "applemusic":
            return AppleMusicClient.currentTrack()
        default:
            if let am = AppleMusicClient.currentTrack(), AppleMusicClient.isPlaying {
                return am
            }
            if let st = try? await SpotifyClient(settings: settings).fetchPlayer() {
                return st.track
            }
            return AppleMusicClient.currentTrack()
        }
    }
}
