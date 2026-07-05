import AppKit

@MainActor
final class NowPlayingWidgetView: NSView {
    private let artworkView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let artistLabel = NSTextField(labelWithString: "")

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 72))

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
        layer?.cornerRadius = 12

        artworkView.imageScaling = .scaleProportionallyUpOrDown
        artworkView.wantsLayer = true
        artworkView.layer?.cornerRadius = 6
        artworkView.layer?.masksToBounds = true

        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail

        artistLabel.font = .systemFont(ofSize: 11)
        artistLabel.textColor = NSColor.white.withAlphaComponent(0.75)
        artistLabel.lineBreakMode = .byTruncatingTail

        for view in [artworkView, titleLabel, artistLabel] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        NSLayoutConstraint.activate([
            artworkView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            artworkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            artworkView.widthAnchor.constraint(equalToConstant: 48),
            artworkView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: centerYAnchor, constant: -16),

            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4)
        ])

        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh),
            name: NowPlayingDisplay.didUpdateNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(applyVisibility),
            name: VisualEffectsSettings.showNowPlayingWidgetChanged, object: nil
        )

        refresh()
        applyVisibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func refresh() {
        titleLabel.stringValue = NowPlayingDisplay.shared.title
        artistLabel.stringValue = NowPlayingDisplay.shared.artist
        artworkView.image = NowPlayingDisplay.shared.artwork
    }

    @objc func applyVisibility() {
        let visible = VisualEffectsSettings.shared.showNowPlayingWidget
        if visible {
            window?.orderFrontRegardless()
        } else {
            window?.orderOut(nil)
        }
    }
}
