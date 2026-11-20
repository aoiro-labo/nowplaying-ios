import Foundation

public struct Track: Codable, Equatable {
    public var title: String
    /// All credited artists, joined the way the source presents them.
    public var artistsJoined: String
    /// First artist segment, used for the iTunes search term.
    public var artistFirst: String
    public var album: String
    /// "spotify" or "applemusic"
    public var source: String
    public var spotifyURL: String?

    public init(title: String, artistsJoined: String, artistFirst: String,
                album: String, source: String, spotifyURL: String?) {
        self.title = title
        self.artistsJoined = artistsJoined
        self.artistFirst = artistFirst
        self.album = album
        self.source = source
        self.spotifyURL = spotifyURL
    }
}
