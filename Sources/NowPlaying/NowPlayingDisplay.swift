import AppKit

@MainActor
final class NowPlayingDisplay {
    static let shared = NowPlayingDisplay()
    static let didUpdateNotification = Notification.Name("NowPlayingDisplay.didUpdate")

    private(set) var title: String = ""
    private(set) var artist: String = ""
    private(set) var artwork: NSImage?

    private init() {}

    func update(title: String, artist: String, artwork: NSImage?) {
        self.title = title
        self.artist = artist
        self.artwork = artwork
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
    }

    func clear() {
        title = ""
        artist = ""
        artwork = nil
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
    }
}
