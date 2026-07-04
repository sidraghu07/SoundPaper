import Accelerate

final class FFTProcessor: AudioSampleConsumer {
    private let fftSize: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private let window: [Float]
    private let sampleRate: Float
    private let hopSize: Int
    private var ringBuffer: [Float] = []

    var energyOnCalculated: (@Sendable (_ bass: Float, _ mid: Float, _ treble: Float) -> Void)?

    init(fftSize: Int = 1024, sampleRate: Float = 44100.0, overlap: Float = 0.5) {
        self.fftSize = fftSize
        self.sampleRate = sampleRate
        self.hopSize = Int(Float(fftSize) * (1.0 - overlap))

        let log2n = vDSP_Length(log2(Float(fftSize)))
        self.log2n = log2n
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!

        var hannWindow = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&hannWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = hannWindow
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func append(samples: [Float]) {
        ringBuffer.append(contentsOf: samples)

        while ringBuffer.count >= fftSize {
            let chunk = Array(ringBuffer.prefix(fftSize))
            var windowed = [Float](repeating: 0, count: fftSize)
            vDSP_vmul(chunk, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

            let magnitudes = forwardFFT(windowed: windowed)
            analyzeBands(magnitudes: magnitudes)
            publishWaveform(chunk: chunk)

            ringBuffer.removeFirst(hopSize)
        }
    }

    private func publishWaveform(chunk: [Float]) {
        let targetCount = WaveformSamples.sampleCount
        let stride = max(1, chunk.count / targetCount)

        var decimated: [Float] = []
        decimated.reserveCapacity(targetCount)
        var i = 0
        while i < chunk.count && decimated.count < targetCount {
            decimated.append(chunk[i])
            i += stride
        }
        while decimated.count < targetCount {
            decimated.append(0)
        }

        WaveformSamples.shared.update(samples: decimated)
    }

    private func forwardFFT(windowed: [Float]) -> [Float] {
        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)

        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)

                windowed.withUnsafeBufferPointer { windowedPtr in
                    windowedPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                    }
                }

                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        return magnitudes
    }

    private func analyzeBands(magnitudes: [Float]) {
        let binWidth = sampleRate / Float(fftSize)
        let halfSize = magnitudes.count 

        func averageEnergy(fromHz: Float, toHz: Float) -> Float {
            let lowBin = max(1, Int(fromHz / binWidth))
            let highBin = min(halfSize, Int(toHz / binWidth))
            guard lowBin < highBin else { return 0 }
            let slice = magnitudes[lowBin..<highBin]
            return slice.reduce(0, +) / Float(slice.count)
        }

        let bass = averageEnergy(fromHz: 20, toHz: 250)
        let mid = averageEnergy(fromHz: 250, toHz: 4000)
        let treble = averageEnergy(fromHz: 4000, toHz: 16000)

        energyOnCalculated?(bass, mid, treble)
    }
}
