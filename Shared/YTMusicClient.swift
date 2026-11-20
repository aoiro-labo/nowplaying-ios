import Foundation

/// One YouTube Music album result.
public struct YTCandidate {
    public let albumTitle: String
    public let artistName: String
    public let year: String
    public let browseId: String
    /// ~540px artwork.
    public let artworkURL: String
    /// ~1080px artwork.
    public let artworkURLHigh: String
    public var pageURL: String { "https://music.youtube.com/browse/\(browseId)" }
}

/// YouTube Music as a metadata source, via the InnerTube endpoint
/// the web client uses (no account or API key needed). Unofficial:
/// the response shape can change without notice, so parsing is
/// defensive and simply yields no candidates on surprises.
public enum YTMusicClient {
    private static let apiKey = "AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30"
    /// InnerTube "albums" filter for the search endpoint.
    private static let albumsFilter = "EgWKAQIYAWoKEAoQAxAEEAUQCg%3D%3D"

    public static func searchAlbums(track: Track) async -> [YTCandidate] {
        let query = track.album.isEmpty ? "\(track.title) \(track.artistFirst)" : track.album
        guard !query.isEmpty,
              let endpoint = URL(string: "https://music.youtube.com/youtubei/v1/search?key=\(apiKey)")
        else { return [] }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
                     forHTTPHeaderField: "User-Agent")
        let body: [String: Any] = [
            "context": ["client": ["clientName": "WEB_REMIX",
                                   "clientVersion": "1.20241127.01.00",
                                   "hl": "ja", "gl": "JP"]],
            "query": query,
            "params": albumsFilter,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var items: [[String: Any]] = []
        collectItems(obj, into: &items)
        let found = items.compactMap(parseItem)
        let albumN = ITunesMatcher.normalizeAlbum(track.album)
        return found.sorted {
            (ITunesMatcher.normalizeAlbum($0.albumTitle) == albumN ? 0 : 1)
                < (ITunesMatcher.normalizeAlbum($1.albumTitle) == albumN ? 0 : 1)
        }
    }

    private static func collectItems(_ o: Any, into items: inout [[String: Any]]) {
        if let d = o as? [String: Any] {
            if let item = d["musicResponsiveListItemRenderer"] as? [String: Any] {
                items.append(item)
            }
            for v in d.values { collectItems(v, into: &items) }
        } else if let a = o as? [Any] {
            for v in a { collectItems(v, into: &items) }
        }
    }

    private static func parseItem(_ item: [String: Any]) -> YTCandidate? {
        guard let nav = item["navigationEndpoint"] as? [String: Any],
              let browse = nav["browseEndpoint"] as? [String: Any],
              let browseId = browse["browseId"] as? String,
              let cols = item["flexColumns"] as? [[String: Any]], cols.count >= 2,
              let title = columnText(cols[0]), !title.isEmpty,
              let thumb = item["thumbnail"] as? [String: Any],
              let mtr = thumb["musicThumbnailRenderer"] as? [String: Any],
              let tObj = mtr["thumbnail"] as? [String: Any],
              let thumbs = tObj["thumbnails"] as? [[String: Any]],
              let last = thumbs.last, let raw = last["url"] as? String else { return nil }
        // Second column: "Album • Artist • Year" style runs.
        var parts = columnRuns(cols[1]).filter { $0 != " • " && !$0.isEmpty }
        let typeLabels: Set<String> = ["アルバム", "シングル", "EP", "プレイリスト",
                                       "Album", "Single", "Playlist"]
        if let first = parts.first, typeLabels.contains(first) { parts.removeFirst() }
        var year = ""
        var artistParts: [String] = []
        for p in parts {
            if p.range(of: #"^\d{4}年?$"#, options: .regularExpression) != nil {
                year = p.replacingOccurrences(of: "年", with: "")
            } else {
                artistParts.append(p)
            }
        }
        return YTCandidate(albumTitle: title,
                           artistName: artistParts.joined(separator: " "),
                           year: year,
                           browseId: browseId,
                           artworkURL: sized(raw, 540),
                           artworkURLHigh: sized(raw, 1080))
    }

    private static func columnRuns(_ col: [String: Any]) -> [String] {
        guard let r = col["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
              let text = r["text"] as? [String: Any],
              let runs = text["runs"] as? [[String: Any]] else { return [] }
        return runs.compactMap { $0["text"] as? String }
    }

    private static func columnText(_ col: [String: Any]) -> String? {
        let runs = columnRuns(col)
        return runs.isEmpty ? nil : runs.joined()
    }

    /// Google image URLs scale by rewriting the trailing =w..-h..
    /// size suffix.
    private static func sized(_ url: String, _ px: Int) -> String {
        guard let r = url.range(of: "=w", options: .backwards) else { return url }
        return String(url[..<r.lowerBound]) + "=w\(px)-h\(px)-l90-rj"
    }
}
