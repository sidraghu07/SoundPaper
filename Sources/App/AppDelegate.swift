import AppKit
import CoreGraphics
import MetalKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [NSWindow] = []
    private var renderers: [WallpaperRenderer] = []
    private var capture: SystemAudioCapture!
    private var isCapturing = false
    private let metalDevice = MTLCreateSystemDefaultDevice()!
    private var nowPlaying: NowPlayingMonitor!
    private var controlsWindow: ControlsWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.module.url(forResource: "app", withExtension: "jpg"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }

        rebuildWindows()
        controlsWindow = ControlsWindow()
        controlsWindow.show()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildWindows),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        let fft = FFTProcessor()
        fft.energyOnCalculated = { bass, mid, treble in
            AudioLevels.shared.update(bass: bass, mid: mid, treble: treble)
        }
        capture = SystemAudioCapture(consumer: fft)

        startCaptureIfPossible()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        nowPlaying = NowPlayingMonitor()
        nowPlaying.onUpdate = { title, artist, artworkData in
            guard let artworkData else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                if let colors = AlbumColorExtractor.getColors(from: artworkData) {
                    CoverColors.shared.update(colors: colors)
                    print("Cover colors for \(title) by \(artist): \(colors)")
                } else {
                    print("Cover color extraction failed for \(title) by \(artist)")
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controlsWindow.show()
        return true
    }

    private func startCaptureIfPossible() {
        guard !isCapturing else { return }
        Task {
            do {
                try await capture.start()
                isCapturing = true
            } catch {
                print("Audio capture not started yet: \(error)")
            }
        }
    }

    @objc private func applicationDidLaunch(_ notification: Notification) {
        guard !isCapturing,
              let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier,
              SystemAudioCapture.musicBundleIDs.contains(bundleID) else { return }
        startCaptureIfPossible()
    }

    @objc private func rebuildWindows() {
        windows.forEach { $0.close() }
        windows.removeAll()
        renderers.removeAll()
        windows = NSScreen.screens.map(makeWallpaperWindow)
    }

    private func makeWallpaperWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isOpaque = true
        window.isReleasedWhenClosed = false

        let metalView = MTKView(frame: CGRect(origin: .zero, size: screen.frame.size), device: metalDevice)
        let renderer = WallpaperRenderer(device: metalDevice)
        metalView.delegate = renderer
        renderers.append(renderer)

        window.contentView = metalView
        window.makeKeyAndOrderFront(nil)
        return window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
