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
    private var captureRetryTimer: Timer?
    private var widgetWindows: [NSWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = ResourceLoader.url(forResource: "app", withExtension: "jpg"),
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
        startCaptureRetryTimer()

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
                let colors = AlbumColorExtractor.getColors(from: artworkData)
                let artworkImage = NSImage(data: artworkData)
                DispatchQueue.main.async {
                    if let colors {
                        CoverColors.shared.update(colors: colors)
                        print("Cover colors for \(title) by \(artist): \(colors)")
                    } else {
                        print("Cover color extraction failed for \(title) by \(artist)")
                    }
                    NowPlayingDisplay.shared.update(title: title, artist: artist, artwork: artworkImage)
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
                captureRetryTimer?.invalidate()
                captureRetryTimer = nil
            } catch {
                let nsError = error as NSError
                let isPermissionDenied = nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && nsError.code == -3801
                if isPermissionDenied {
                    print("Screen Recording permission not granted. Grant it in System Settings > Privacy & Security > Screen Recording, then relaunch the app.")
                    captureRetryTimer?.invalidate()
                    captureRetryTimer = nil
                } else {
                    print("Audio capture not started yet: \(error)")
                }
            }
        }
    }
    private func startCaptureRetryTimer() {
        captureRetryTimer?.invalidate()
        captureRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard !self.isCapturing else {
                    self.captureRetryTimer?.invalidate()
                    self.captureRetryTimer = nil
                    return
                }
                self.startCaptureIfPossible()
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
        widgetWindows.forEach { $0.close() }
        widgetWindows.removeAll()
        windows = NSScreen.screens.map(makeWallpaperWindow)
        widgetWindows = NSScreen.screens.map(makeNowPlayingWidgetWindow)
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

    private func makeNowPlayingWidgetWindow(for screen: NSScreen) -> NSWindow {
        let widgetSize = CGSize(width: 280, height: 72)
        let origin = CGPoint(x: screen.frame.minX + 24, y: screen.frame.minY + 24)
        let window = NSWindow(
            contentRect: CGRect(origin: origin, size: widgetSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true

        let widget = NowPlayingWidgetView()
        widget.frame = CGRect(origin: .zero, size: widgetSize)
        window.contentView = widget
        widget.applyVisibility()
        return window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
