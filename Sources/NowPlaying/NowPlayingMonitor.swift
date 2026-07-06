import AppKit

private typealias GetNowPlayingInfoBlock = @convention(c) (
    DispatchQueue,
    @escaping ([String: Any]) -> Void
) -> Void

private typealias RegisterForNowPlayingNotificationsBlock = @convention(c) (DispatchQueue) -> Void

private typealias GetNowPlayingApplicationPIDBlock = @convention(c) (
    DispatchQueue,
    @escaping (Int32) -> Void
) -> Void

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

private let getNowPlayingApplicationPID: GetNowPlayingApplicationPIDBlock = {
    guard let handle = mediaRemoteHandle,
          let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") else {
        fatalError("MRMediaRemoteGetNowPlayingApplicationPID not found")
    }

    return unsafeBitCast(symbol, to: GetNowPlayingApplicationPIDBlock.self)
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

    func reset() {
        lastTitle = nil
        lastArtist = nil
    }

    func refresh() {
        getNowPlayingApplicationPID(.main) { [weak self] pid in
            guard let self else { return }
            guard pid > 0,
                  let app = NSRunningApplication(processIdentifier: pid),
                  app.bundleIdentifier == VisualEffectsSettings.shared.audioSource.bundleID else {
                return
            }
            getNowPlayingInfo(.main) { info in
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
}