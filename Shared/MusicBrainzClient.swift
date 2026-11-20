import Foundation

/// One MusicBrainz release, with its Cover Art Archive artwork.
public struct MBCandidate {
    public var releaseTitle: String
    public var artistName: String
    public var releaseID: String
    public var date: String

    public var artworkURL: String {
        "https://coverartarchive.org/release/\(releaseID)/front-500"
    }
    public var artworkURLHigh: String {
        "https://coverartarchive.org/release/\(releaseID)/front-1200"
    }
    public var pageURL: String {
        "https://musicbrainz.org/release/\(releaseID)"
    }
}

/// MusicBrainz release search + Cover Art Archive artwork. Most
/// commercial releases (CD and digital) are in MusicBrainz even when
/// store metadata differs in notation, so its releases serve as extra
/// artwork candidates and as a fallback when iTunes has no artwork.
public enum MusicBrainzClient {
    public static func searchReleases(track: Track) async -> [MBCandidate] {
        guard !track.album.isEmpty else { return [] }
        // Search by release title only: MusicBrainz artist credits
        // often differ from the store's artist string (an ensemble
        // name vs the individual singers), so an AND artist clause
        // misses the release entirely. Exact-title matches are
        // sorted first below instead.
        let q = "release:\"\(escape(track.album))\""
        var comps = URLComponents(string: "https://musicbrainz.org/ws/2/release/")!
        comps.queryItems = [
            URLQueryItem(name: "query", value: q),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: "10"),
        ]
        guard let url = comps.url else { return [] }
        var req = URLRequest(url: url)
        req.setValue("NowPlaying/1.7 ( https://github.com/aoiro-labo/nowplaying-ios )",
                     forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let releases = obj["releases"] as? [[String: Any]] else { return [] }
        let found: [MBCandidate] = releases.compactMap { r in
            guard let id = r["id"] as? String,
                  let title = r["title"] as? String else { return nil }
            let credit = (r["artist-credit"] as? [[String: Any]])?
                .compactMap { ($0["artist"] as? [String: Any])?["name"] as? String }
                .joined(separator: ", ") ?? ""
            return MBCandidate(releaseTitle: title,
                               artistName: credit,
                               releaseID: id,
                               date: (r["date"] as? String) ?? "")
        }
        let albumN = ITunesMatcher.normalizeAlbum(track.album)
        return found.sorted {
            (ITunesMatcher.normalizeAlbum($0.releaseTitle) == albumN ? 0 : 1)
                < (ITunesMatcher.normalizeAlbum($1.releaseTitle) == albumN ? 0 : 1)
        }
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
