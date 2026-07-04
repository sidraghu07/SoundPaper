import Foundation

final class WaveformSamples: @unchecked Sendable {
    static let shared = WaveformSamples()
    static let sampleCount = 512

    private let lock = NSLock()
    private var samples: [Float] = Array(repeating: 0, count: WaveformSamples.sampleCount)

    private init() {}

    func update(samples: [Float]) {
        lock.lock()
        self.samples = samples
        lock.unlock()
    }

    func getSamples() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }
}
