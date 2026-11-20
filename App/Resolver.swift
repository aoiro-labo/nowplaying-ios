import Foundation

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
        switch settings.source {
        case "spotify":
            return try? await SpotifyClient(settings: settings).fetchPlayer().track
        case "applemusic":
            return AppleMusicClient.currentTrack()
        default:
            return await resolveAuto(settings: settings)
        }
    }

    private static func resolveAuto(settings: NPSettings) async -> Track? {
        let spotifyTask = Task { try? await SpotifyClient(settings: settings).fetchPlayer() }
        let appleTrack = AppleMusicClient.currentTrack()
        let applePlaying = appleTrack != nil && AppleMusicClient.isPlaying
        let spotify = await spotifyTask.value

        // 1. Spotify playing on this device.
        if let st = spotify, st.isPlaying, st.isThisDevice { return st.track }
        // 2. Apple Music playing on this device.
        if applePlaying, let am = appleTrack { return am }
        // 3. Spotify paused on this device (just paused here).
        if let st = spotify, st.isThisDevice { return st.track }
        // 4. Apple Music paused track on this device.
        if let am = appleTrack { return am }
        // 5. Anything Spotify reports elsewhere, rather than nothing.
        return spotify?.track
    }
}
