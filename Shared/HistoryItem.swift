import Foundation

/// One entry in the fetch history: the track, the post text that was
/// composed for it at fetch time, and a small artwork thumbnail.
public struct HistoryItem: Codable {
    public var track: Track
    public var text: String
    public var date: Date
    public var artworkData: Data?

    public init(track: Track, text: String, date: Date, artworkData: Data? = nil) {
        self.track = track
        self.text = text
        self.date = date
        self.artworkData = artworkData
    }
}
