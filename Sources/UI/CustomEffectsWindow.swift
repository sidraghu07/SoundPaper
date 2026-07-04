import AppKit

@MainActor
final class CustomEffectsWindow: NSObject {
    let window: NSWindow

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 200),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Custom Effects"
        window.isReleasedWhenClosed = false
        window.center()

        super.init()

        let kaleidoscopeCheckbox = NSButton(checkboxWithTitle: "Kaleidoscope", target: self, action: #selector(toggleKaleidoscope(_:)))
        kaleidoscopeCheckbox.state = VisualEffectsSettings.shared.kaleidoscope ? .on : .off

        let echoCheckbox = NSButton(checkboxWithTitle: "Echo Trails", target: self, action: #selector(toggleEchoTrails(_:)))
        echoCheckbox.state = VisualEffectsSettings.shared.echoTrails ? .on : .off

        let chromaticCheckbox = NSButton(checkboxWithTitle: "Chromatic Aberration", target: self, action: #selector(toggleChromaticAberration(_:)))
        chromaticCheckbox.state = VisualEffectsSettings.shared.chromaticAberration ? .on : .off

        let hueCheckbox = NSButton(checkboxWithTitle: "Hue Cycling", target: self, action: #selector(toggleHueCycling(_:)))
        hueCheckbox.state = VisualEffectsSettings.shared.hueCycling ? .on : .off

        let stack = NSStackView(views: [kaleidoscopeCheckbox, echoCheckbox, chromaticCheckbox, hueCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20)
        ])

        window.contentView = container
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleKaleidoscope(_ sender: NSButton) {
        VisualEffectsSettings.shared.kaleidoscope = sender.state == .on
    }

    @objc private func toggleEchoTrails(_ sender: NSButton) {
        VisualEffectsSettings.shared.echoTrails = sender.state == .on
    }

    @objc private func toggleChromaticAberration(_ sender: NSButton) {
        VisualEffectsSettings.shared.chromaticAberration = sender.state == .on
    }

    @objc private func toggleHueCycling(_ sender: NSButton) {
        VisualEffectsSettings.shared.hueCycling = sender.state == .on
    }
}
