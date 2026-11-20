import SwiftUI
import Foundation

/// Probe for the private MediaRemote framework. App Store apps cannot
/// use this, but a sideloaded app can try: if
/// MRMediaRemoteGetNowPlayingInfo returns the system-wide now playing
/// info (any app: Spotify, Music, ...), the app can behave much more
/// like its Android counterparts.
enum MediaRemote {
    private static let handle: UnsafeMutableRawPointer? =
        dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)

    static var isAvailable: Bool { handle != nil }

    typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping @convention(block) ([String: Any]?) -> Void) -> Void
    typealias GetIsPlayingFn = @convention(c) (DispatchQueue, @escaping @convention(block) (Bool) -> Void) -> Void

    static func fetchInfo(completion: @escaping ([String: Any]?) -> Void) {
        guard let handle, let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
            completion(nil)
            return
        }
        let fn = unsafeBitCast(sym, to: GetInfoFn.self)
        fn(DispatchQueue.main, completion)
    }

    static func fetchIsPlaying(completion: @escaping (Bool?) -> Void) {
        guard let handle, let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") else {
            completion(nil)
            return
        }
        let fn = unsafeBitCast(sym, to: GetIsPlayingFn.self)
        fn(DispatchQueue.main) { completion($0) }
    }
}

struct MediaRemoteProbeView: View {
    @State private var log: String = "Not run yet. Play something in Spotify or Music, then tap Run."
    @State private var running = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Button {
                    run()
                } label: {
                    Label("Run probe", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.borderedProminent)
                .disabled(running)
                ScrollView {
                    Text(log)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding()
            .navigationTitle("MediaRemote probe")
        }
    }

    private func run() {
        running = true
        var lines: [String] = []
        lines.append("framework loaded: \(MediaRemote.isAvailable)")
        MediaRemote.fetchIsPlaying { isPlaying in
            lines.append("appIsPlaying: \(isPlaying.map(String.init(describing:)) ?? "nil")")
            MediaRemote.fetchInfo { info in
                defer { running = false }
                guard let info else {
                    lines.append("info: nil")
                    log = lines.joined(separator: "\n")
                    return
                }
                lines.append("info keys: \(info.count)")
                for key in info.keys.sorted() {
                    let v = info[key]
                    if let s = v as? String {
                        lines.append("\(key) = \(s)")
                    } else if let n = v as? NSNumber {
                        lines.append("\(key) = \(n)")
                    } else if let d = v as? Data {
                        lines.append("\(key) = <Data \(d.count) bytes>")
                    } else if let v {
                        lines.append("\(key) = <\(type(of: v))>")
                    }
                }
                log = lines.joined(separator: "\n")
            }
        }
    }
}
