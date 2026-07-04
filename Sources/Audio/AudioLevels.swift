import Foundation

final class AudioLevels: @unchecked Sendable {
    static let shared = AudioLevels()
    private let lock = NSLock()
    private var bass: Float = 0
    private var mid: Float = 0
    private var treble: Float = 0

    private init() {}

    func update(bass: Float, mid: Float, treble: Float) {
        lock.lock()
        let smoothing: Float = 0.15
        self.bass += (bass - self.bass) * smoothing
        self.mid += (mid - self.mid) * smoothing
        self.treble += (treble - self.treble) * smoothing
        lock.unlock()
    }

    func getLevels() -> (bass: Float, mid: Float, treble: Float) {
        lock.lock()
        defer { lock.unlock() }
        return (bass, mid, treble)
    }
}