import Foundation

final class VisualEffectsSettings: @unchecked Sendable {
    static let shared = VisualEffectsSettings()

    private let lock = NSLock()
    private var _kaleidoscope = false
    private var _echoTrails = false
    private var _chromaticAberration = false
    private var _hueCycling = false
    private var _atmosphereMode = 0

    private init() {}

    var atmosphereMode: Int {
        get { lock.lock(); defer { lock.unlock() }; return _atmosphereMode }
        set { lock.lock(); _atmosphereMode = newValue; lock.unlock() }
    }

    var kaleidoscope: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _kaleidoscope }
        set { lock.lock(); _kaleidoscope = newValue; lock.unlock() }
    }

    var echoTrails: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _echoTrails }
        set { lock.lock(); _echoTrails = newValue; lock.unlock() }
    }

    var chromaticAberration: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _chromaticAberration }
        set { lock.lock(); _chromaticAberration = newValue; lock.unlock() }
    }

    var hueCycling: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _hueCycling }
        set { lock.lock(); _hueCycling = newValue; lock.unlock() }
    }
}
