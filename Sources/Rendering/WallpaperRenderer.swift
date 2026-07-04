import MetalKit
import simd

struct WallpaperUniforms {
    var time: Float
    var bass: Float
    var mid: Float
    var treble: Float
    var colorCount: Float
    var kaleidoscopeEnabled: Float
    var echoTrailsEnabled: Float
    var chromaticAberrationEnabled: Float
    var hueCyclingEnabled: Float
    var atmosphereMode: Float
    var puddleTime: Float
    var oceanTime: Float
    var color0: SIMD4<Float>
    var color1: SIMD4<Float>
    var color2: SIMD4<Float>
    var color3: SIMD4<Float>
    var color4: SIMD4<Float>
    var color5: SIMD4<Float>
    var color6: SIMD4<Float>
    var color7: SIMD4<Float>
}

private let paletteSlotCount = 8

final class WallpaperRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let startTime = CACurrentMediaTime()
    private var puddleTime: Float = 0
    private var oceanTime: Float = 0
    private var lastFrameTimestamp = CACurrentMediaTime()

    init(device: MTLDevice) {
        self.commandQueue = device.makeCommandQueue()!

        guard let shaderURL = Bundle.module.url(forResource: "Shaders", withExtension: "metal"),
              let shaderSource = try? String(contentsOf: shaderURL, encoding: .utf8) else {
            fatalError("Could not locate Shaders.metal in the resource bundle")
        }

        guard let library = try? device.makeLibrary(source: shaderSource, options: nil),
              let vertexFunction = library.makeFunction(name: "vertexMain"),
              let fragmentFunction = library.makeFunction(name: "fragmentMain") else {
            fatalError("Could not compile Metal shaders")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        self.pipelineState = try! device.makeRenderPipelineState(descriptor: descriptor)
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        let now = CACurrentMediaTime()
        let deltaTime = Float(now - lastFrameTimestamp)
        lastFrameTimestamp = now

        let levels = AudioLevels.shared.getLevels()
        let midN = min(1, max(0, levels.mid / 40))
        let bassN = min(1, max(0, levels.bass / 3000))
        puddleTime += deltaTime * (0.3 + midN * 0.4)
        oceanTime += deltaTime * (0.25 + bassN * 0.3)

        let palette = CoverColors.shared.getColors()
        let paddedColors = (0..<paletteSlotCount).map { i -> SIMD4<Float> in
            guard i < palette.count else { return SIMD4<Float>(palette.first ?? SIMD3(0.1, 0.3, 0.6), 1) }
            return SIMD4<Float>(palette[i], 1)
        }

        let settings = VisualEffectsSettings.shared

        var uniforms = WallpaperUniforms(
            time: Float(CACurrentMediaTime() - startTime),
            bass: levels.bass,
            mid: levels.mid,
            treble: levels.treble,
            colorCount: Float(max(1, min(palette.count, paletteSlotCount))),
            kaleidoscopeEnabled: settings.kaleidoscope ? 1 : 0,
            echoTrailsEnabled: settings.echoTrails ? 1 : 0,
            chromaticAberrationEnabled: settings.chromaticAberration ? 1 : 0,
            hueCyclingEnabled: settings.hueCycling ? 1 : 0,
            atmosphereMode: Float(settings.atmosphereMode),
            puddleTime: puddleTime,
            oceanTime: oceanTime,
            color0: paddedColors[0],
            color1: paddedColors[1],
            color2: paddedColors[2],
            color3: paddedColors[3],
            color4: paddedColors[4],
            color5: paddedColors[5],
            color6: paddedColors[6],
            color7: paddedColors[7]
        )

        let waveform = WaveformSamples.shared.getSamples()

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<WallpaperUniforms>.stride, index: 0)
        waveform.withUnsafeBytes { rawBuffer in
            encoder.setFragmentBytes(rawBuffer.baseAddress!, length: rawBuffer.count, index: 1)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
