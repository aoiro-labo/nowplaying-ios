import Foundation

public struct ITunesMatch {
    public var artworkURL100: String
    public var trackViewURL: String
}

/// iTunes Search lookup with the album-match selection the shortcut
/// version settled on: among up to 5 song results, pick the one whose
/// collection name matches the track's album (suffixes like " - EP"
/// ignored). For Apple Music tracks the track name must match too.
/// Falls back to the first result when nothing matches.
public enum ITunesMatcher {
    public static func normalizeAlbum(_ s: String) -> String {
        var t = s
        for suf in [" - EP", " - Single", " - Album"] where t.hasSuffix(suf) {
            t = String(t.dropLast(suf.count))
        }
        return t
    }

    public static func search(track: Track, quality: String) async -> (match: ITunesMatch?, artworkData: Data?) {
        var comps = URLComponents(string: "https://itunes.apple.com/search")!
        comps.queryItems = [
            URLQueryItem(name: "term", value: "\(track.title) \(track.artistFirst)"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "5"),
            URLQueryItem(name: "country", value: "JP"),
        ]
        guard let url = comps.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = obj["results"] as? [[String: Any]],
              !results.isEmpty else {
            return (nil, nil)
        }
        let albumN = normalizeAlbum(track.album)
        var chosen: [String: Any]? = nil
        for r in results {
            guard let coll = r["collectionName"] as? String,
                  normalizeAlbum(coll) == albumN else { continue }
            if track.source == "applemusic",
               (r["trackName"] as? String) != track.title { continue }
            chosen = r
            break
        }
        let pick = chosen ?? results[0]
        guard let art = pick["artworkUrl100"] as? String else { return (nil, nil) }
        let match = ITunesMatch(artworkURL100: art,
                                trackViewURL: (pick["trackViewUrl"] as? String) ?? "")
        var artData: Data? = nil
        let wanted = quality == "high"
            ? art.replacingOccurrences(of: "100x100bb", with: "1200x1200bb")
            : art
        if let u = URL(string: wanted), let (d, _) = try? await URLSession.shared.data(from: u) {
            artData = d
        } else if quality == "high", let u = URL(string: art),
                  let (d, _) = try? await URLSession.shared.data(from: u) {
            artData = d
        }
        return (match, artData)
    }
}
