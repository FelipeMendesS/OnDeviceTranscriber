//
//  AudioRecorderService.swift
//  OnDeviceTranscriber
//
//  Handles audio recording using AVAudioEngine.
//  Supports both manual stop (UI) and automatic stop via VAD (Shortcuts).
//

import Foundation
import AVFoundation
import Combine
import AudioToolbox

#if os(iOS)
import UIKit
#endif

/// Service responsible for recording audio from the microphone.
/// Uses AVAudioEngine for low-latency access to audio buffers.
@MainActor
final class AudioRecorderService: ObservableObject {

    // MARK: - Published State

    /// Whether the recorder is currently recording
    @Published private(set) var isRecording = false

    /// Current audio level (0.0 to 1.0) for UI visualization
    @Published private(set) var audioLevel: Float = 0

    /// Duration of current recording in seconds
    @Published private(set) var recordingDuration: TimeInterval = 0

    // MARK: - Private Properties

    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private var recordingStartTime: Date?
    private var durationTimer: Timer?

    // VAD (Voice Activity Detection) properties
    private var silenceStartTime: Date?
    private var vadContinuation: CheckedContinuation<[Float], Error>?
    private var currentVADConfig: (threshold: Float, silenceDuration: TimeInterval)?

    // Track if we're in background mode
    private var isBackgroundRecording = false

    // MARK: - Recording Control

    /// Starts recording audio from the microphone.
    /// - Parameter forBackground: If true, configures for background Shortcut recording
    /// - Throws: `TranscriptionError.recordingStartFailed` if recording cannot start.
    func startRecording(forBackground: Bool = false) throws {
        guard !isRecording else { return }

        isBackgroundRecording = forBackground

        // Configure audio session (iOS only)
        // Use background-specific configuration if running from Shortcut
        #if os(iOS)
        do {
            if forBackground {
                try configureAudioSessionForBackground()
            } else {
                try configureAudioSession()
            }
        } catch {
            throw TranscriptionError.recordingStartFailed(underlying: error)
        }
        #endif

        // Reset state
        audioBuffer = []
        silenceStartTime = nil
        recordingStartTime = Date()
        recordingDuration = 0

        // Reset the audio engine to ensure clean state
        audioEngine.reset()

        // Get the input node and its format
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Validate format
        guard recordingFormat.sampleRate > 0 else {
            throw TranscriptionError.recordingStartFailed(underlying: nil)
        }

        // Install tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.processAudioBuffer(buffer)
            }
        }

        // Start the audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            startDurationTimer()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw TranscriptionError.recordingStartFailed(underlying: error)
        }
    }

    /// Stops recording and returns the captured audio buffer.
    /// - Returns: Array of audio samples as Float values, resampled to 16kHz.
    func stopRecording() -> [Float] {
        guard isRecording else { return [] }

        // Stop engine and remove tap
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Stop timer
        durationTimer?.invalidate()
        durationTimer = nil

        // Update state
        isRecording = false
        audioLevel = 0

        // Deactivate audio session (iOS only)
        deactivateAudioSession()

        // Resample to 16kHz for WhisperKit
        let inputSampleRate = audioEngine.inputNode.outputFormat(forBus: 0).sampleRate
        let resampledBuffer = resampleTo16kHz(audioBuffer, fromSampleRate: inputSampleRate)

        return resampledBuffer
    }

    /// Cancels recording without returning data.
    func cancelRecording() {
        guard isRecording else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        durationTimer?.invalidate()
        durationTimer = nil

        isRecording = false
        audioLevel = 0
        audioBuffer = []

        deactivateAudioSession()

        // If VAD is waiting, cancel it
        vadContinuation?.resume(throwing: TranscriptionError.cancelled)
        vadContinuation = nil
    }

    // MARK: - VAD Recording (for Shortcuts)

    /// Records audio until silence is detected or max duration is reached.
    /// Used by App Intents where there's no UI to manually stop.
    ///
    /// - Parameters:
    ///   - silenceThreshold: Audio level below which is considered silence
    ///   - silenceDuration: How long silence must persist before stopping
    ///   - maxDuration: Maximum recording duration regardless of speech
    ///   - playFeedback: Whether to play audio/haptic feedback
    ///   - forBackground: Whether this is a background Shortcut recording
    /// - Returns: Array of audio samples resampled to 16kHz
    /// - Throws: `TranscriptionError` if recording fails
    func recordWithVAD(
        silenceThreshold: Float = TranscriptionConfig.silenceThreshold,
        silenceDuration: TimeInterval = TranscriptionConfig.silenceDurationToStop,
        maxDuration: TimeInterval = TranscriptionConfig.maxRecordingDuration,
        playFeedback: Bool = false,
        forBackground: Bool = false
    ) async throws -> [Float] {

        // Store VAD config for use in checkVAD
        currentVADConfig = (silenceThreshold, silenceDuration)

        // Play start feedback if requested
        if playFeedback {
            playStartFeedback()
        }

        // Small delay after feedback to ensure audio session is ready
        if playFeedback {
            try await Task.sleep(for: .milliseconds(300))
        }

        // Start recording with appropriate audio session config
        try startRecording(forBackground: forBackground)

        // Wait for VAD to trigger or max duration
        let buffer: [Float] = try await withCheckedThrowingContinuation { continuation in
            self.vadContinuation = continuation

            // Set up max duration timeout
            Task {
                try await Task.sleep(for: .seconds(maxDuration))

                // If still recording after max duration, stop
                if self.isRecording {
                    let buffer = self.stopRecording()
                    self.vadContinuation?.resume(returning: buffer)
                    self.vadContinuation = nil
                }
            }

            // VAD monitoring is done in processAudioBuffer
        }

        // Clear VAD config
        currentVADConfig = nil

        // Play stop feedback if requested
        if playFeedback {
            playStopFeedback()
        }

        return buffer
    }

    /// Records audio for background Shortcuts with longer silence detection.
    /// Uses 5-second silence threshold and provides audio/haptic feedback.
    /// Configures audio session specifically for background operation.
    ///
    /// - Returns: Array of audio samples resampled to 16kHz
    /// - Throws: `TranscriptionError` if recording fails
    func recordForBackgroundShortcut() async throws -> [Float] {
        return try await recordWithVAD(
            silenceThreshold: TranscriptionConfig.backgroundSilenceThreshold,
            silenceDuration: TranscriptionConfig.backgroundSilenceDuration,
            maxDuration: TranscriptionConfig.backgroundMaxDuration,
            playFeedback: true,
            forBackground: true  // Use background audio session config
        )
    }

    // MARK: - Audio Feedback

    /// Plays feedback sound and haptic when recording starts
    private func playStartFeedback() {
        // Play system sound (begin recording tone)
        AudioServicesPlaySystemSound(1113) // Begin recording sound

        // Haptic feedback on iOS
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

    /// Plays feedback sound and haptic when recording stops
    private func playStopFeedback() {
        // Play system sound (end recording tone)
        AudioServicesPlaySystemSound(1114) // End recording sound

        // Haptic feedback on iOS
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    // MARK: - Private Methods

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))

        // Append to our buffer
        audioBuffer.append(contentsOf: samples)

        // Calculate audio level for UI
        let level = calculateRMSLevel(samples)
        audioLevel = level

        // VAD logic (only if waiting for VAD)
        if vadContinuation != nil {
            checkVAD(level: level)
        }
    }

    private func checkVAD(level: Float) {
        // Use stored config or fall back to defaults
        let threshold = currentVADConfig?.threshold ?? TranscriptionConfig.silenceThreshold
        let requiredSilenceDuration = currentVADConfig?.silenceDuration ?? TranscriptionConfig.silenceDurationToStop

        if level < threshold {
            // Below threshold - might be silence
            if silenceStartTime == nil {
                silenceStartTime = Date()
            } else if let start = silenceStartTime,
                      Date().timeIntervalSince(start) >= requiredSilenceDuration {
                // Silence duration exceeded - stop recording
                let buffer = stopRecording()
                vadContinuation?.resume(returning: buffer)
                vadContinuation = nil
                silenceStartTime = nil
            }
        } else {
            // Above threshold - reset silence timer
            silenceStartTime = nil
        }
    }

    private func calculateRMSLevel(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }

        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(samples.count))

        // Normalize to 0-1 range (assuming max amplitude of 1.0)
        // Apply some scaling for better visual feedback
        return min(rms * 5, 1.0)
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    /// Resamples audio from the input sample rate to 16kHz for WhisperKit.
    private func resampleTo16kHz(_ samples: [Float], fromSampleRate inputRate: Double) -> [Float] {
        let targetRate = Double(TranscriptionConfig.sampleRate)

        // If already at target rate, return as-is
        if abs(inputRate - targetRate) < 1 {
            return samples
        }

        // Simple linear interpolation resampling
        let ratio = inputRate / targetRate
        let outputCount = Int(Double(samples.count) / ratio)

        var output = [Float](repeating: 0, count: outputCount)

        for i in 0..<outputCount {
            let srcIndex = Double(i) * ratio
            let srcIndexInt = Int(srcIndex)
            let fraction = Float(srcIndex - Double(srcIndexInt))

            if srcIndexInt + 1 < samples.count {
                output[i] = samples[srcIndexInt] * (1 - fraction) + samples[srcIndexInt + 1] * fraction
            } else if srcIndexInt < samples.count {
                output[i] = samples[srcIndexInt]
            }
        }

        return output
    }
}

// MARK: - Audio Buffer Utilities

extension AudioRecorderService {
    /// Saves the current audio buffer to a temporary WAV file.
    /// Useful for debugging or when file-based input is needed.
    /// - Returns: URL to the temporary WAV file
    func saveToTemporaryFile() throws -> URL {
        let buffer = audioBuffer
        guard !buffer.isEmpty else {
            throw TranscriptionError.noAudioCaptured
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        // Create WAV file with 16kHz sample rate
        let inputSampleRate = audioEngine.inputNode.outputFormat(forBus: 0).sampleRate
        let resampled = resampleTo16kHz(buffer, fromSampleRate: inputSampleRate)

        try writeWAVFile(samples: resampled, sampleRate: TranscriptionConfig.sampleRate, to: tempURL)

        return tempURL
    }

    private func writeWAVFile(samples: [Float], sampleRate: Int, to url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!

        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        let frameCount = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw TranscriptionError.noAudioCaptured
        }

        buffer.frameLength = frameCount

        // Copy samples to buffer
        let channelData = buffer.floatChannelData![0]
        for (index, sample) in samples.enumerated() {
            channelData[index] = sample
        }

        try audioFile.write(from: buffer)
    }
}
