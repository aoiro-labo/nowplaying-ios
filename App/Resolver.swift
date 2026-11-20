import Foundation

/// A resolved track plus whether it is actually playing (vs paused).
public struct ResolvedTrack {
    public var track: Track
    public var isPlaying: Bool
}

/// Source resolution. "auto" means: prefer what is actually playing
/// on THIS device.
///
/// Both sides are consulted, because neither flag alone is reliable
/// here: the Music player's playbackState can still report playing
/// after playback moved to Spotify (the same MediaRemote flakiness
/// the shortcut version hit), while /me/player says authoritatively
/// whether Spotify is playing and on which device. So a Spotify
/// track playing on this device beats an Apple track even when the
/// Music player claims to be playing, and a paused track on another
/// device never beats a track on this one.
public enum Resolver {
    public static func resolve(settings: NPSettings) async -> Track? {
        await resolveDetailed(settings: settings)?.track
    }

    public static func resolveDetailed(settings: NPSettings) async -> ResolvedTrack? {
        switch settings.source {
        case "spotify":
            guard let st = try? await SpotifyClient(settings: settings).fetchPlayer() else { return nil }
            return ResolvedTrack(track: st.track, isPlaying: st.isPlaying)
        case "applemusic":
            guard let t = AppleMusicClient.currentTrack() else { return nil }
            return ResolvedTrack(track: t, isPlaying: AppleMusicClient.isPlaying)
        case "lastfm":
            guard let r = try? await LastFmClient.fetchRecent(username: settings.lastfmUsername,
                                                              apiKey: settings.lastfmAPIKey)
            else { return nil }
            return ResolvedTrack(track: r.track, isPlaying: r.isPlaying)
        default:
            return await resolveAuto(settings: settings)
        }
    }

    private static func resolveAuto(settings: NPSettings) async -> ResolvedTrack? {
        let spotifyTask = Task { try? await SpotifyClient(settings: settings).fetchPlayer() }
        let appleTrack = AppleMusicClient.currentTrack()
        let applePlaying = appleTrack != nil && AppleMusicClient.isPlaying
        let spotify = await spotifyTask.value

        // 1. Spotify playing on this device.
        if let st = spotify, st.isPlaying, st.isThisDevice {
            return ResolvedTrack(track: st.track, isPlaying: true)
        }
        // 2. Apple Music playing on this device.
        if applePlaying, let am = appleTrack {
            return ResolvedTrack(track: am, isPlaying: true)
        }
        // 3. Spotify paused on this device (just paused here).
        if let st = spotify, st.isThisDevice {
            return ResolvedTrack(track: st.track, isPlaying: false)
        }
        // 4. Apple Music paused track on this device.
        if let am = appleTrack {
            return ResolvedTrack(track: am, isPlaying: false)
        }
        // 5. Anything Spotify reports elsewhere, rather than nothing.
        if let st = spotify {
            return ResolvedTrack(track: st.track, isPlaying: st.isPlaying)
        }
        return nil
    }
}
