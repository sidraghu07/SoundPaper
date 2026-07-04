import AppKit

@MainActor
final class ControlsWindow: NSObject {
    let window: NSWindow
    private var customWindow: CustomEffectsWindow?

    private struct Preset {
        let name: String
        let kaleidoscope: Bool
        let echoTrails: Bool
        let chromaticAberration: Bool
        let hueCycling: Bool
    }

    private let presets: [Preset] = [
        Preset(name: "Clean Waveform", kaleidoscope: false, echoTrails: false, chromaticAberration: false, hueCycling: false),
        Preset(name: "Echo Trails", kaleidoscope: false, echoTrails: true, chromaticAberration: false, hueCycling: false),
        Preset(name: "Kaleidoscope", kaleidoscope: true, echoTrails: false, chromaticAberration: false, hueCycling: false),
        Preset(name: "Trippy (All Effects)", kaleidoscope: true, echoTrails: true, chromaticAberration: true, hueCycling: true)
    ]

    private let atmospheres: [String] = ["Waveform", "Puddle", "Space", "Ocean"]

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Wallpaper Controls"
        window.isReleasedWhenClosed = false
        window.center()

        super.init()

        let atmosphereLabel = NSTextField(labelWithString: "Atmosphere")
        atmosphereLabel.font = .boldSystemFont(ofSize: 12)

        var atmosphereButtons: [NSButton] = []
        for (index, name) in atmospheres.enumerated() {
            let button = NSButton(radioButtonWithTitle: name, target: self, action: #selector(atmosphereSelected(_:)))
            button.tag = index
            button.state = (VisualEffectsSettings.shared.atmosphereMode == index) ? .on : .off
            atmosphereButtons.append(button)
        }
        let atmosphereStack = NSStackView(views: atmosphereButtons)
        atmosphereStack.orientation = .vertical
        atmosphereStack.alignment = .leading
        atmosphereStack.spacing = 6

        let effectsLabel = NSTextField(labelWithString: "Effects")
        effectsLabel.font = .boldSystemFont(ofSize: 12)

        let currentEffects = VisualEffectsSettings.shared
        var presetButtons: [NSButton] = []
        for (index, preset) in presets.enumerated() {
            let button = NSButton(radioButtonWithTitle: preset.name, target: self, action: #selector(presetSelected(_:)))
            button.tag = index
            let matchesCurrent = preset.kaleidoscope == currentEffects.kaleidoscope
                && preset.echoTrails == currentEffects.echoTrails
                && preset.chromaticAberration == currentEffects.chromaticAberration
                && preset.hueCycling == currentEffects.hueCycling
            button.state = matchesCurrent ? .on : .off
            presetButtons.append(button)
        }
        let customButton = NSButton(radioButtonWithTitle: "Custom...", target: self, action: #selector(customSelected(_:)))
        customButton.tag = -1
        presetButtons.append(customButton)

        let effectsStack = NSStackView(views: presetButtons)
        effectsStack.orientation = .vertical
        effectsStack.alignment = .leading
        effectsStack.spacing = 6

        let outerStack = NSStackView(views: [atmosphereLabel, atmosphereStack, effectsLabel, effectsStack])
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 14
        outerStack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            outerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            outerStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20)
        ])

        window.contentView = container
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func atmosphereSelected(_ sender: NSButton) {
        VisualEffectsSettings.shared.atmosphereMode = sender.tag
    }

    @objc private func presetSelected(_ sender: NSButton) {
        let preset = presets[sender.tag]
        VisualEffectsSettings.shared.kaleidoscope = preset.kaleidoscope
        VisualEffectsSettings.shared.echoTrails = preset.echoTrails
        VisualEffectsSettings.shared.chromaticAberration = preset.chromaticAberration
        VisualEffectsSettings.shared.hueCycling = preset.hueCycling
    }

    @objc private func customSelected(_ sender: NSButton) {
        if customWindow == nil {
            customWindow = CustomEffectsWindow()
        }
        customWindow?.show()
    }
}
