import Foundation
import simd

final class CoverColors: @unchecked Sendable {
    static let shared = CoverColors()

    private let lock = NSLock()
    private var colors: [SIMD3<Float>] = []

    private init() {}

    func update(colors: [SIMD3<Float>]) {
        lock.lock()
        self.colors = colors
        lock.unlock()
    }

    func getColors() -> [SIMD3<Float>] {
        lock.lock()
        defer { lock.unlock() }
        return colors
    }
}
