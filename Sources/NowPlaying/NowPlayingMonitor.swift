import Foundation

private typealias GetNowPlayingInfoBlock = @convention(c) (
    DispatchQueue,
    @escaping ([String: Any]) -> Void
) -> Void

private typealias RegisterForNowPlayingNotificationsBlock = @convention(c) (DispatchQueue) -> Void

nonisolated(unsafe) private let mediaRemoteHandle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)

private let getNowPlayingInfo: GetNowPlayingInfoBlock = {
    guard let handle = mediaRemoteHandle,
    let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
        fatalError("MRMediaRemoteGetNowPlayingInfo not found")
    }

    return unsafeBitCast(symbol, to: GetNowPlayingInfoBlock.self)
}()

private let registerForNowPlayingNotificationsBlock: RegisterForNowPlayingNotificationsBlock = {
    guard let handle = mediaRemoteHandle,
          let symbol = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") else {
        fatalError("MRMediaRemoteRegisterForNowPlayingNotifications not found")
    }

    return unsafeBitCast(symbol, to: RegisterForNowPlayingNotificationsBlock.self)
}()

final class NowPlayingMonitor: @unchecked Sendable {
    var onUpdate: ((_ title: String, _ artist: String, _ artworkData: Data?) -> Void)?

    private var lastTitle: String?
    private var lastArtist: String?

    init() {
        registerForNowPlayingNotificationsBlock(.main)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) {
            [weak self] _ in self?.refresh()
        }
        refresh()
    }

    func refresh() {
        getNowPlayingInfo(.main) { [weak self] info in
            guard let self else { return }
            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            guard let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data,
                  !artworkData.isEmpty else { return }
            guard title != self.lastTitle || artist != self.lastArtist else { return }
            self.lastTitle = title
            self.lastArtist = artist
            self.onUpdate?(title, artist, artworkData)
        }
    }
}