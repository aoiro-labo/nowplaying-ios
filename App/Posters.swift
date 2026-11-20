import Foundation
import CryptoKit

/// Direct posting clients: X API (OAuth 1.0a), Bluesky (AT Protocol),
/// Mastodon and Misskey. Each takes the composed text and optional artwork.
enum PosterError: Error, LocalizedError {
    case notConfigured(String)
    case http(Int, String)
    case badResponse(String)
    var errorDescription: String? {
        switch self {
        case .notConfigured(let s): return "Not configured: \(s)"
        case .http(let code, let body): return "HTTP \(code): \(String(body.prefix(300)))"
        case .badResponse(let s): return s
        }
    }
}

private func pctEncode(_ s: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
}

private func httpData(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let h = resp as? HTTPURLResponse else { throw PosterError.badResponse("No HTTP response") }
    return (data, h)
}

private func requireOK(_ h: HTTPURLResponse, _ data: Data) throws {
    guard (200..<300).contains(h.statusCode) else {
        throw PosterError.http(h.statusCode, String(data: data, encoding: .utf8) ?? "")
    }
}

private struct MultipartPart {
    var name: String
    var filename: String? = nil
    var contentType: String? = nil
    var data: Data
}

private func multipartRequest(url: URL, parts: [MultipartPart], headers: [String: String] = [:]) -> URLRequest {
    let boundary = "Boundary-\(UUID().uuidString)"
    var body = Data()
    for p in parts {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        var disp = "Content-Disposition: form-data; name=\"\(p.name)\""
        if let f = p.filename { disp += "; filename=\"\(f)\"" }
        body.append((disp + "\r\n").data(using: .utf8)!)
        if let ct = p.contentType { body.append("Content-Type: \(ct)\r\n".data(using: .utf8)!) }
        body.append("\r\n".data(using: .utf8)!)
        body.append(p.data)
        body.append("\r\n".data(using: .utf8)!)
    }
    body.append("--\(boundary)--\r\n".data(using: .utf8)!)
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
    req.httpBody = body
    return req
}

private func jsonRequest(url: URL, json: [String: Any], headers: [String: String] = [:]) -> URLRequest {
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
    req.httpBody = try? JSONSerialization.data(withJSONObject: json)
    return req
}

// MARK: - X API (OAuth 1.0a)

enum XPoster {
    static func oauthHeader(method: String, url: URL, consumerKey: String, consumerSecret: String, token: String, tokenSecret: String) -> String {
        var params: [String: String] = [
            "oauth_consumer_key": consumerKey,
            "oauth_nonce": UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            "oauth_signature_method": "HMAC-SHA1",
            "oauth_timestamp": String(Int(Date().timeIntervalSince1970)),
            "oauth_token": token,
            "oauth_version": "1.0",
        ]
        let paramString = params.keys.sorted().map { "\(pctEncode($0))=\(pctEncode(params[$0]!))" }.joined(separator: "&")
        let base = [method.uppercased(), pctEncode(url.absoluteString), pctEncode(paramString)].joined(separator: "&")
        let signingKey = "\(pctEncode(consumerSecret))&\(pctEncode(tokenSecret))"
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: Data(base.utf8), using: SymmetricKey(data: Data(signingKey.utf8)))
        params["oauth_signature"] = Data(mac).base64EncodedString()
        let header = params.keys.sorted().map { "\(pctEncode($0))=\"\(pctEncode(params[$0]!))\"" }.joined(separator: ", ")
        return "OAuth \(header)"
    }

    static func post(text: String, imageData: Data?, s: NPSettings) async throws {
        guard !s.xConsumerKey.isEmpty, !s.xConsumerSecret.isEmpty,
              !s.xAccessToken.isEmpty, !s.xAccessTokenSecret.isEmpty else {
            throw PosterError.notConfigured("X API")
        }
        var mediaIDs: [String] = []
        if let img = imageData {
            let url = URL(string: "https://upload.twitter.com/1.1/media/upload.json")!
            var req = multipartRequest(url: url, parts: [
                MultipartPart(name: "media", filename: "artwork.jpg", contentType: "image/jpeg", data: img),
            ])
            req.setValue(oauthHeader(method: "POST", url: url, consumerKey: s.xConsumerKey, consumerSecret: s.xConsumerSecret, token: s.xAccessToken, tokenSecret: s.xAccessTokenSecret), forHTTPHeaderField: "Authorization")
            let (data, h) = try await httpData(req)
            try requireOK(h, data)
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let mid = obj?["media_id_string"] as? String else {
                throw PosterError.badResponse("No media_id in X upload response")
            }
            mediaIDs.append(mid)
        }
        let url = URL(string: "https://api.twitter.com/2/tweets")!
        var payload: [String: Any] = ["text": text]
        if !mediaIDs.isEmpty { payload["media"] = ["media_ids": mediaIDs] }
        var req = jsonRequest(url: url, json: payload)
        req.setValue(oauthHeader(method: "POST", url: url, consumerKey: s.xConsumerKey, consumerSecret: s.xConsumerSecret, token: s.xAccessToken, tokenSecret: s.xAccessTokenSecret), forHTTPHeaderField: "Authorization")
        let (data, h) = try await httpData(req)
        try requireOK(h, data)
    }
}

// MARK: - Bluesky (AT Protocol)

enum BlueskyPoster {
    static func post(text: String, imageData: Data?, s: NPSettings) async throws {
        guard !s.bskyHandle.isEmpty, !s.bskyAppPassword.isEmpty else {
            throw PosterError.notConfigured("Bluesky")
        }
        let server = s.bskyServer.isEmpty ? "bsky.social" : s.bskyServer
        let base = "https://\(server)"
        let loginReq = jsonRequest(url: URL(string: "\(base)/xrpc/com.atproto.server.createSession")!,
                                   json: ["identifier": s.bskyHandle, "password": s.bskyAppPassword])
        let (d1, h1) = try await httpData(loginReq)
        try requireOK(h1, d1)
        let sess = try JSONSerialization.jsonObject(with: d1) as? [String: Any]
        guard let jwt = sess?["accessJwt"] as? String, let did = sess?["did"] as? String else {
            throw PosterError.badResponse("Bluesky login failed")
        }
        var record: [String: Any] = [
            "$type": "app.bsky.feed.post",
            "text": text,
            "createdAt": isoNow(),
        ]
        if let img = imageData {
            var up = URLRequest(url: URL(string: "\(base)/xrpc/com.atproto.repo.uploadBlob")!)
            up.httpMethod = "POST"
            up.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
            up.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            up.httpBody = img
            let (d2, h2) = try await httpData(up)
            try requireOK(h2, d2)
            guard let blob = (try JSONSerialization.jsonObject(with: d2) as? [String: Any])?["blob"] else {
                throw PosterError.badResponse("Bluesky upload failed")
            }
            record["embed"] = [
                "$type": "app.bsky.embed.images",
                "images": [["alt": "", "image": blob]],
            ]
        }
        let req = jsonRequest(url: URL(string: "\(base)/xrpc/com.atproto.repo.createRecord")!,
                              json: ["repo": did, "collection": "app.bsky.feed.post", "record": record],
                              headers: ["Authorization": "Bearer \(jwt)"])
        let (d3, h3) = try await httpData(req)
        try requireOK(h3, d3)
    }

    private static func isoNow() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date())
    }
}

// MARK: - Mastodon

enum MastodonPoster {
    static func post(text: String, imageData: Data?, s: NPSettings) async throws {
        guard !s.mastodonInstance.isEmpty, !s.mastodonToken.isEmpty else {
            throw PosterError.notConfigured("Mastodon")
        }
        let base = "https://\(s.mastodonInstance)"
        let auth = ["Authorization": "Bearer \(s.mastodonToken)"]
        var mediaIDs: [String] = []
        if let img = imageData {
            let req = multipartRequest(url: URL(string: "\(base)/api/v1/media")!,
                                       parts: [MultipartPart(name: "file", filename: "artwork.jpg", contentType: "image/jpeg", data: img)],
                                       headers: auth)
            let (d, h) = try await httpData(req)
            try requireOK(h, d)
            let obj = try JSONSerialization.jsonObject(with: d) as? [String: Any]
            guard let mid = obj?["id"] as? String else {
                throw PosterError.badResponse("Mastodon media upload failed")
            }
            mediaIDs.append(mid)
        }
        var payload: [String: Any] = ["status": text]
        if !mediaIDs.isEmpty { payload["media_ids"] = mediaIDs }
        let req = jsonRequest(url: URL(string: "\(base)/api/v1/statuses")!, json: payload, headers: auth)
        let (d, h) = try await httpData(req)
        try requireOK(h, d)
    }
}

// MARK: - Misskey

enum MisskeyPoster {
    static func post(text: String, imageData: Data?, s: NPSettings) async throws {
        guard !s.misskeyInstance.isEmpty, !s.misskeyToken.isEmpty else {
            throw PosterError.notConfigured("Misskey")
        }
        let base = "https://\(s.misskeyInstance)"
        var fileIDs: [String] = []
        if let img = imageData {
            let req = multipartRequest(url: URL(string: "\(base)/api/drive/files/create")!,
                                       parts: [
                                           MultipartPart(name: "i", data: Data(s.misskeyToken.utf8)),
                                           MultipartPart(name: "file", filename: "artwork.jpg", contentType: "image/jpeg", data: img),
                                       ])
            let (d, h) = try await httpData(req)
            try requireOK(h, d)
            let obj = try JSONSerialization.jsonObject(with: d) as? [String: Any]
            guard let fid = obj?["id"] as? String else {
                throw PosterError.badResponse("Misskey file upload failed")
            }
            fileIDs.append(fid)
        }
        var payload: [String: Any] = ["i": s.misskeyToken, "text": text]
        if !fileIDs.isEmpty { payload["fileIds"] = fileIDs }
        let req = jsonRequest(url: URL(string: "\(base)/api/notes/create")!, json: payload)
        let (d, h) = try await httpData(req)
        try requireOK(h, d)
    }
}
