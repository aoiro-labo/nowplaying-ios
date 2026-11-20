import Foundation
import MediaPlayer

/// Reads the Music app's now-playing item. This is the same data the
/// Shortcuts "Current Song" action returns: when another app is
/// playing, the item is a placeholder with an empty artist, which the
/// health gate below rejects (same rule as the shortcut version).
public enum AppleMusicClient {
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
}
