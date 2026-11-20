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
        let q = "release:\"\(escape(track.album))\" AND artist:\"\(escape(track.artistFirst))\""
        var comps = URLComponents(string: "https://musicbrainz.org/ws/2/release/")!
        comps.queryItems = [
            URLQueryItem(name: "query", value: q),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: "5"),
        ]
        guard let url = comps.url else { return [] }
        var req = URLRequest(url: url)
        req.setValue("NowPlaying/1.7 ( https://github.com/aoiro-labo/nowplaying-app )",
                     forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let releases = obj["releases"] as? [[String: Any]] else { return [] }
        return releases.compactMap { r in
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
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
