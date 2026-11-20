import Foundation

public struct ITunesMatch {
    public var artworkURL100: String
    public var trackViewURL: String
}

/// One iTunes search result, kept around so the user can pick a
/// different artwork by hand and so a wrong pick can be reported with
/// the full candidate list.
public struct ITunesCandidate {
    public var trackName: String
    public var artistName: String
    public var collectionName: String
    public var artworkURL100: String
    public var trackViewURL: String

    public var match: ITunesMatch {
        ITunesMatch(artworkURL100: artworkURL100, trackViewURL: trackViewURL)
    }
}

/// iTunes Search lookup. Selection prefers an exact match, in tiers:
/// 1. track + album + artist, 2. track + album, 3. album only,
/// 4. the first result. Comparisons are normalized: album suffixes
/// (" - EP" / " - Single" / " - Album") are stripped, full-width
/// punctuation is folded to half-width, spaces are removed, and a
/// trailing " - X" in a title is treated as "(X)" (Spotify writes
/// "檄! 帝国華撃団 - 改" where Apple writes "檄! 帝国華撃団 (改)").
public enum ITunesMatcher {
    public static func normalizeAlbum(_ s: String) -> String {
        var t = s
        for suf in [" - EP", " - Single", " - Album"] where t.hasSuffix(suf) {
            t = String(t.dropLast(suf.count))
        }
        return normalizeCommon(t)
    }

    public static func normalizeTitle(_ s: String) -> String {
        var t = s
        if let r = t.range(of: " - ", options: .backwards) {
            t = String(t[..<r.lowerBound]) + "(" + String(t[r.upperBound...]) + ")"
        }
        return normalizeCommon(t)
    }

    public static func normalizeArtist(_ s: String) -> String {
        normalizeCommon(s)
    }

    private static func normalizeCommon(_ s: String) -> String {
        var t = s
        for (a, b) in [("！", "!"), ("？", "?"), ("（", "("), ("）", ")"),
                       ("：", ":"), ("／", "/"), ("　", "")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        return t.replacingOccurrences(of: " ", with: "")
    }

    public static func search(track: Track, quality: String) async
        -> (match: ITunesMatch?, artworkData: Data?, candidates: [ITunesCandidate]) {
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
            return (nil, nil, [])
        }
        let candidates: [ITunesCandidate] = results.compactMap { r in
            guard let art = r["artworkUrl100"] as? String else { return nil }
            return ITunesCandidate(trackName: (r["trackName"] as? String) ?? "",
                                   artistName: (r["artistName"] as? String) ?? "",
                                   collectionName: (r["collectionName"] as? String) ?? "",
                                   artworkURL100: art,
                                   trackViewURL: (r["trackViewUrl"] as? String) ?? "")
        }
        guard !candidates.isEmpty else { return (nil, nil, []) }

        let albumN = normalizeAlbum(track.album)
        let titleN = normalizeTitle(track.title)
        let artistsN = normalizeArtist(track.artistsJoined)
        let artistFirstN = normalizeArtist(track.artistFirst)
        func albumOK(_ c: ITunesCandidate) -> Bool { normalizeAlbum(c.collectionName) == albumN }
        func titleOK(_ c: ITunesCandidate) -> Bool { normalizeTitle(c.trackName) == titleN }
        func artistOK(_ c: ITunesCandidate) -> Bool {
            let a = normalizeArtist(c.artistName)
            return a == artistsN || a == artistFirstN
        }
        let pick = candidates.first { titleOK($0) && albumOK($0) && artistOK($0) }
            ?? candidates.first { titleOK($0) && albumOK($0) }
            ?? candidates.first { albumOK($0) }
            ?? candidates[0]

        var artData: Data? = nil
        let wanted = quality == "high"
            ? pick.artworkURL100.replacingOccurrences(of: "100x100bb", with: "1200x1200bb")
            : pick.artworkURL100
        if let u = URL(string: wanted), let (d, _) = try? await URLSession.shared.data(from: u) {
            artData = d
        } else if quality == "high", let u = URL(string: pick.artworkURL100),
                  let (d, _) = try? await URLSession.shared.data(from: u) {
            artData = d
        }
        return (pick.match, artData, candidates)
    }
}
