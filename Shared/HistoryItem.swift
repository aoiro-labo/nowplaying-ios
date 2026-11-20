import Foundation

/// One entry in the fetch history: the track and the post text that was
/// composed for it at fetch time.
public struct HistoryItem: Codable {
    public var track: Track
    public var text: String
    public var date: Date

    public init(track: Track, text: String, date: Date) {
        self.track = track
        self.text = text
        self.date = date
    }
}
