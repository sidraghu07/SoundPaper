import Foundation
import CoreGraphics
import ImageIO
import simd

enum AlbumColorExtractor {
    static func getColors(from data: Data, maxColors: Int = 8) -> [SIMD3<Float>]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let size = 64
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Explicit high-quality interpolation so a detailed, busy cover gets a
        // true area-weighted downsample instead of a cheap approximation that
        // can wash out saturated regions into duller averages.
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let pixelData = context.data else { return nil }
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: size * size * 4)

        // Build a histogram from every pixel, unfiltered - matches how Apple
        // Music's own extraction (based on the classic "ColorArt" algorithm)
        // finds its background color first: album backgrounds are frequently
        // dark, muted, or near-black, so filtering by saturation/brightness
        // up front (like earlier versions of this code did) biases away from
        // ever finding the real background at all.
        var buckets: [Int: (count: Int, r: Int, g: Int, b: Int)] = [:]
        let quantizeStep = 24

        for i in 0..<(size * size) {
            let offset = i * 4
            let r = Int(pixels[offset])
            let g = Int(pixels[offset + 1])
            let b = Int(pixels[offset + 2])

            let key = (r / quantizeStep) << 16 | (g / quantizeStep) << 8 | (b / quantizeStep)
            var bucket = buckets[key] ?? (0, 0, 0, 0)
            bucket.count += 1
            bucket.r += r
            bucket.g += g
            bucket.b += b
            buckets[key] = bucket
        }

        let byFrequency = buckets.values.sorted { $0.count > $1.count }

        // Find the background from a coarser re-bucketing pass, not the fine
        // histogram above. A region with natural shading/gradient variation
        // (e.g. varied reds across a photo) gets its pixel mass fragmented
        // across many nearby fine buckets, so even a small but perfectly
        // uniform region (e.g. solid black text) can out-count any single
        // one of them despite covering far less of the actual image. Coarser
        // buckets merge similar shades together so total area wins properly.
        var coarseBuckets: [Int: (count: Int, r: Int, g: Int, b: Int)] = [:]
        let coarseStep = 48
        for i in 0..<(size * size) {
            let offset = i * 4
            let r = Int(pixels[offset])
            let g = Int(pixels[offset + 1])
            let b = Int(pixels[offset + 2])
            let key = (r / coarseStep) << 16 | (g / coarseStep) << 8 | (b / coarseStep)
            var bucket = coarseBuckets[key] ?? (0, 0, 0, 0)
            bucket.count += 1
            bucket.r += r
            bucket.g += g
            bucket.b += b
            coarseBuckets[key] = bucket
        }

        guard let backgroundBucket = coarseBuckets.values.max(by: { $0.count < $1.count }) else { return nil }
        let background = SIMD3<Float>(Float(backgroundBucket.r), Float(backgroundBucket.g), Float(backgroundBucket.b))
            / Float(backgroundBucket.count) / 255

        // Accent colors: rank the rest by count, but boost genuinely
        // saturated buckets - otherwise a small real accent (e.g. a splash of
        // orange on an otherwise gray/black cover) gets crowded out of the
        // top slots by sheer pixel count from the dominant neutral tones.
        // This mirrors ColorArt's "find primary/secondary/detail colors that
        // contrast with the background" step.
        let accentCandidates = byFrequency.sorted { a, b in
            let colorA = SIMD3<Float>(Float(a.r), Float(a.g), Float(a.b)) / Float(a.count) / 255
            let colorB = SIMD3<Float>(Float(b.r), Float(b.g), Float(b.b)) / Float(b.count) / 255
            let scoreA = Float(a.count) * (1 + rgbToHSV(colorA).s * 3)
            let scoreB = Float(b.count) * (1 + rgbToHSV(colorB).s * 3)
            return scoreA > scoreB
        }

        var picked: [SIMD3<Float>] = [background]
        let minDistance: Float = 0.22
        for bucket in accentCandidates {
            let color = SIMD3<Float>(Float(bucket.r), Float(bucket.g), Float(bucket.b)) / Float(bucket.count) / 255
            let isDistinct = picked.allSatisfy { simd.distance($0, color) > minDistance }
            if isDistinct {
                picked.append(color)
            }
            if picked.count == maxColors {
                break
            }
        }

        // Treat as effectively grayscale only if NOTHING in the palette is
        // genuinely saturated. Hue clustering alone isn't a useful signal -
        // most real album art has a cohesive color scheme (e.g. a bouquet of
        // reds and golds), which clusters hues together just as much as an
        // actual sepia-tinted black-and-white photo does. The one thing that
        // actually distinguishes them is whether any color is truly vivid.
        let maxSaturation = picked.map { rgbToHSV($0).s }.max() ?? 0
        let isEffectivelyGrayscale = picked.isEmpty || maxSaturation < 0.3
        if isEffectivelyGrayscale {
            picked = extractGrayscalePalette(pixels: pixels, pixelCount: size * size, maxColors: maxColors)
            guard !picked.isEmpty else { return nil }

            // Pad with more shades of gray - a black-and-white cover should
            // only ever produce black/white/gray, never an invented hue.
            while picked.count < 2 {
                let v = picked[0].x
                let shifted = max(0, min(1, v > 0.5 ? v - 0.3 : v + 0.3))
                picked.append(SIMD3<Float>(repeating: shifted))
            }

            return picked
        }

        var rotation: Float = 180
        while picked.count < 2 {
            picked.append(hueRotated(picked[0], by: rotation))
            rotation = 120
        }

        return picked
    }

    private static func extractGrayscalePalette(pixels: UnsafeMutablePointer<UInt8>, pixelCount: Int, maxColors: Int) -> [SIMD3<Float>] {
        var brightnessBuckets: [Int: (count: Int, total: Int)] = [:]
        let brightnessStep = 24

        for i in 0..<pixelCount {
            let offset = i * 4
            let r = Int(pixels[offset])
            let g = Int(pixels[offset + 1])
            let b = Int(pixels[offset + 2])
            let brightness = (r + g + b) / 3
            guard brightness > 5, brightness < 250 else { continue }

            let key = brightness / brightnessStep
            var bucket = brightnessBuckets[key] ?? (0, 0)
            bucket.count += 1
            bucket.total += brightness
            brightnessBuckets[key] = bucket
        }

        let sortedBrightness = brightnessBuckets.values.sorted { $0.count > $1.count }
        guard !sortedBrightness.isEmpty else { return [] }

        let levels = min(maxColors, max(2, sortedBrightness.count))
        var colors: [SIMD3<Float>] = []

        for bucket in sortedBrightness.prefix(levels) {
            let v = Float(bucket.total) / Float(bucket.count) / 255
            colors.append(SIMD3<Float>(repeating: v))
        }

        return colors
    }

    private static func hueRotated(_ color: SIMD3<Float>, by degrees: Float) -> SIMD3<Float> {
        let (h, s, v) = rgbToHSV(color)
        var newHue = (h + degrees / 360).truncatingRemainder(dividingBy: 1)
        if newHue < 0 { newHue += 1 }
        return hsvToRGB(h: newHue, s: s, v: v)
    }

    private static func rgbToHSV(_ c: SIMD3<Float>) -> (h: Float, s: Float, v: Float) {
        let maxC = max(c.x, c.y, c.z)
        let minC = min(c.x, c.y, c.z)
        let delta = maxC - minC
        var h: Float = 0
        if delta > 0 {
            if maxC == c.x {
                h = ((c.y - c.z) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == c.y {
                h = (c.z - c.x) / delta + 2
            } else {
                h = (c.x - c.y) / delta + 4
            }
            h /= 6
            if h < 0 { h += 1 }
        }
        let s = maxC == 0 ? 0 : delta / maxC
        return (h, s, maxC)
    }

    private static func hsvToRGB(h: Float, s: Float, v: Float) -> SIMD3<Float> {
        let i = Int(h * 6)
        let f = h * 6 - Float(i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        switch i % 6 {
        case 0: return SIMD3(v, t, p)
        case 1: return SIMD3(q, v, p)
        case 2: return SIMD3(p, v, t)
        case 3: return SIMD3(p, q, v)
        case 4: return SIMD3(t, p, v)
        default: return SIMD3(v, p, q)
        }
    }
}
