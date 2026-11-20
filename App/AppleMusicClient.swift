import Foundation
import MediaPlayer

/// Reads the Music app's now-playing item. This is the same data the
/// Shortcuts "Current Song" action returns: when another app is
/// playing, the item is a placeholder with an empty artist, which the
/// health gate below rejects (same rule as the shortcut version).
public enum AppleMusicClient {
    /// Whether the Music app is actually playing right now. The
    /// now-playing item alone can be a stale, paused track, so the
    /// auto resolver uses this to tell live playback from leftovers.
    public static var isPlaying: Bool {
        MPMusicPlayerController.systemMusicPlayer.playbackState == .playing
    }

    public static func currentTrack() -> Track? {
        let player = MPMusicPlayerController.systemMusicPlayer
        guard let item = player.nowPlayingItem else { return nil }
        let title = item.title ?? ""
        let artist = item.artist ?? ""
        guard !title.isEmpty, !artist.isEmpty else { return nil }
        let album = item.albumTitle ?? ""
        let first = artist.components(separatedBy: "&").first?
            .trimmingCharacters(in: .whitespaces) ?? artist
        return Track(title: title,
                     artistsJoined: artist,
                     artistFirst: first,
                     album: album,
                     source: "applemusic",
                     spotifyURL: nil)
    }

    /// The now-playing item's own artwork, used as a fallback when the
    /// iTunes match has no artwork and as a manual pick option.
    public static func currentArtworkData() -> Data? {
        guard let item = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem,
              let art = item.artwork,
              let img = art.image(at: CGSize(width: 600, height: 600)) else { return nil }
        return img.jpegData(compressionQuality: 0.9) ?? img.pngData()
    }
}
