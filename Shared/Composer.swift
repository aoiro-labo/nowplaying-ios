import Foundation

public struct ComposedPost {
    public var text: String
    public var trackURL: String
}

/// Builds the post text with the shortcut version's semantics:
/// {track} {artist} {album} {url} macros in the format template; when
/// the template has no {url}, the URL mode decides whether the track
/// URL is appended after a space or a newline (or not at all).
public enum Composer {
    public static func compose(track: Track, itunes: ITunesMatch?, settings: NPSettings) -> ComposedPost {
        let trackURL = track.source == "spotify"
            ? (track.spotifyURL ?? "")
            : (itunes?.trackViewURL ?? "")
        let format = settings.format
        var text = format
            .replacingOccurrences(of: "{track}", with: track.title)
            .replacingOccurrences(of: "{artist}", with: track.artistsJoined)
            .replacingOccurrences(of: "{album}", with: track.album)
            .replacingOccurrences(of: "{url}", with: trackURL)
        if !format.contains("{url}"), !trackURL.isEmpty {
            switch settings.urlMode {
            case "space": text += " " + trackURL
            case "newline": text += "\n" + trackURL
            default: break
            }
        }
        return ComposedPost(text: text, trackURL: trackURL)
    }
}
