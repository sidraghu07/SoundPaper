import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreAudio

protocol AudioSampleConsumer {
    func append(samples: [Float])
}

final class SystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    static let musicBundleIDs: Set<String> = ["com.spotify.client", "com.apple.Music"]

    private var stream: SCStream?
    private let consumer: AudioSampleConsumer
    private let sampleRate: Int

    init(consumer: AudioSampleConsumer, sampleRate: Int = 44100) {
        self.consumer = consumer
        self.sampleRate = sampleRate
    }

    func start() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )
        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let musicApps = content.applications.filter { Self.musicBundleIDs.contains($0.bundleIdentifier) }
        guard !musicApps.isEmpty else {
            throw CaptureError.noMusicAppRunning
        }

        let filter = SCContentFilter(display: display, including: musicApps, exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = sampleRate
        config.channelCount = 1
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "audio.capture.queue"))
        try await stream.startCapture()
        self.stream = stream    
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let samples = Self.extractSamples(from: sampleBuffer) else { return }
        consumer.append(samples: samples)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error)")
    }

    private static func extractSamples(from sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let formatDescription = sampleBuffer.formatDescription,
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }
        let asbd = asbdPointer.pointee
        guard asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 else { return nil }

        guard let blockBuffer = sampleBuffer.dataBuffer else { return nil }

        var lengthAtOffset = 0
        var totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer, atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )
        guard status == kCMBlockBufferNoErr, let dataPointer else { return nil }

        let sampleCount = totalLength / MemoryLayout<Float>.size
        let floatPointer = UnsafeRawPointer(dataPointer).assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: floatPointer, count: sampleCount))
    }

    enum CaptureError: Error {
        case noDisplay
        case noMusicAppRunning
    }
}