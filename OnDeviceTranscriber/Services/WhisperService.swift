//
//  WhisperService.swift
//  OnDeviceTranscriber
//
//  Core transcription service using WhisperKit.
//  Singleton pattern ensures model is loaded once and shared between UI and App Intents.
//

import Foundation
import WhisperKit
import Combine
import AVFoundation

// MARK: - Configuration

/// Configurable constants for transcription behavior.
/// Adjust these values to tune VAD sensitivity and other parameters.
enum TranscriptionConfig: Sendable {
    // MARK: Voice Activity Detection (VAD) - In-App UI

    /// Audio level (RMS) below which is considered silence.
    /// Range: 0.0 to 1.0. Lower = more sensitive to quiet sounds.
    /// **Iterate on this value if VAD stops too early or too late.**
    static let silenceThreshold: Float = 0.01

    /// Seconds of continuous silence before auto-stopping recording.
    /// **Iterate on this value to adjust pause tolerance.**
    static let silenceDurationToStop: TimeInterval = 3.0

    /// Maximum recording duration in seconds (safety limit).
    static let maxRecordingDuration: TimeInterval = 300 // 5 minutes

    // MARK: Voice Activity Detection (VAD) - Background Shortcuts

    /// Silence threshold for background recording.
    /// Same as regular threshold by default.
    static let backgroundSilenceThreshold: Float = 0.01

    /// Seconds of silence before auto-stopping in background mode.
    /// **Longer than in-app to allow natural pauses while speaking.**
    /// **ITERATE ON THIS VALUE: Adjust if recording stops too early or too late.**
    static let backgroundSilenceDuration: TimeInterval = 5.0

    /// Maximum recording duration for background shortcuts.
    static let backgroundMaxDuration: TimeInterval = 300 // 5 minutes

    // MARK: Model Settings

    /// Default WhisperKit model to use.
    /// Options: "tiny", "small", "base", "distil-large-v3"
    /// Using distil-large-v3 for best Portuguese accuracy.
    static let defaultModel = "distil-large-v3"

    /// Default language for transcription.
    /// Use "pt" for Portuguese, "en" for English, or nil for auto-detect.
    static let defaultLanguage: String? = "pt"

    // MARK: Audio Settings

    /// Sample rate expected by WhisperKit (do not change).
    static let sampleRate: Int = 16000
}

// MARK: - WhisperService

/// Main transcription service using WhisperKit.
/// Use `WhisperService.shared` to access the singleton instance.
@MainActor
final class WhisperService: ObservableObject {

    // MARK: - Singleton

    /// Shared instance used by both UI and App Intents.
    static let shared = WhisperService()

    // MARK: - Published State

    /// Whether a model is currently loaded and ready for transcription
    @Published private(set) var isModelLoaded = false

    /// Whether the model is currently being downloaded
    @Published private(set) var isDownloading = false

    /// Download/load progress (0.0 to 1.0)
    @Published private(set) var loadProgress: Float = 0

    /// Current status message for UI display
    @Published private(set) var statusMessage = "Ready"

    /// Whether a transcription is currently in progress
    @Published private(set) var isTranscribing = false

    // MARK: - Private Properties

    private var whisperKit: WhisperKit?
    private var currentModelName: String?
    private let audioRecorder = AudioRecorderService()

    // MARK: - Initialization

    private init() {
        // Private init for singleton
    }

    // MARK: - Model Management

    /// Loads the specified WhisperKit model.
    /// Downloads the model if not already cached.
    ///
    /// - Parameter modelName: Name of the model to load (default: from config)
    /// - Throws: `TranscriptionError.modelDownloadFailed` or `modelLoadFailed`
    func loadModel(named modelName: String = TranscriptionConfig.defaultModel) async throws {
        // Skip if already loaded with same model
        if isModelLoaded && currentModelName == modelName {
            return
        }

        isDownloading = true
        loadProgress = 0
        statusMessage = "Preparing model..."

        do {
            statusMessage = "Downloading model (this may take a while)..."

            // Initialize WhisperKit - it will download and load the model
            whisperKit = try await WhisperKit(model: modelName)

            isModelLoaded = true
            currentModelName = modelName
            isDownloading = false
            loadProgress = 1.0
            statusMessage = "Ready"

        } catch {
            isDownloading = false
            isModelLoaded = false
            loadProgress = 0
            statusMessage = "Model load failed"
            throw TranscriptionError.modelLoadFailed(underlying: error)
        }
    }

    /// Checks if the model is downloaded (cached) without loading it.
    func isModelDownloaded(modelName: String = TranscriptionConfig.defaultModel) -> Bool {
        return isModelLoaded && currentModelName == modelName
    }

    // MARK: - Transcription Methods

    /// Transcribes audio from a buffer of float samples.
    ///
    /// - Parameters:
    ///   - audioBuffer: Array of audio samples (16kHz, mono, Float)
    ///   - language: Language code (nil for auto-detect)
    /// - Returns: `TranscriptionResult` with the transcribed text
    /// - Throws: `TranscriptionError` if transcription fails
    func transcribe(
        audioBuffer: [Float],
        language: String? = TranscriptionConfig.defaultLanguage
    ) async throws -> TranscriptionResult {
        guard isModelLoaded, let whisperKit = whisperKit else {
            throw TranscriptionError.modelNotDownloaded
        }

        guard !audioBuffer.isEmpty else {
            throw TranscriptionError.noAudioCaptured
        }

        isTranscribing = true
        statusMessage = "Transcribing..."

        let startTime = Date()
        let audioDuration = Double(audioBuffer.count) / Double(TranscriptionConfig.sampleRate)

        defer {
            isTranscribing = false
            statusMessage = "Ready"
        }

        do {
            // Configure decoding options
            var options = DecodingOptions()
            options.language = language
            options.task = .transcribe
            options.skipSpecialTokens = true
            options.withoutTimestamps = true

            // Perform transcription
            let results = try await whisperKit.transcribe(
                audioArray: audioBuffer,
                decodeOptions: options
            )

            let transcriptionDuration = Date().timeIntervalSince(startTime)

            // Combine all segments into one text
            let text = results
                .compactMap { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            // Check if any speech was detected
            if text.isEmpty {
                throw TranscriptionError.noSpeechDetected
            }

            // Get detected language from first result
            let detectedLanguage = results.first?.language ?? language ?? "unknown"

            return TranscriptionResult(
                text: text,
                language: detectedLanguage,
                audioDuration: audioDuration,
                transcriptionDuration: transcriptionDuration,
                confidence: nil
            )

        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.transcriptionFailed(underlying: error)
        }
    }

    /// Transcribes audio from a file URL.
    ///
    /// - Parameters:
    ///   - fileURL: URL to the audio file (WAV, M4A, MP3, etc.)
    ///   - language: Language code (nil for auto-detect)
    /// - Returns: `TranscriptionResult` with the transcribed text
    /// - Throws: `TranscriptionError` if transcription fails
    func transcribe(
        fileURL: URL,
        language: String? = TranscriptionConfig.defaultLanguage
    ) async throws -> TranscriptionResult {
        guard isModelLoaded, let whisperKit = whisperKit else {
            throw TranscriptionError.modelNotDownloaded
        }

        isTranscribing = true
        statusMessage = "Processing audio file..."

        let startTime = Date()

        defer {
            isTranscribing = false
            statusMessage = "Ready"
        }

        do {
            // Load and convert audio file to samples
            let audioArray = try await loadAudioFile(url: fileURL)

            guard !audioArray.isEmpty else {
                throw TranscriptionError.invalidAudioFile
            }

            let audioDuration = Double(audioArray.count) / Double(TranscriptionConfig.sampleRate)

            // Configure decoding options
            var options = DecodingOptions()
            options.language = language
            options.task = .transcribe
            options.skipSpecialTokens = true
            options.withoutTimestamps = true

            // Perform transcription
            let results = try await whisperKit.transcribe(
                audioArray: audioArray,
                decodeOptions: options
            )

            let transcriptionDuration = Date().timeIntervalSince(startTime)

            // Combine all segments
            let text = results
                .compactMap { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            if text.isEmpty {
                throw TranscriptionError.noSpeechDetected
            }

            let detectedLanguage = results.first?.language ?? language ?? "unknown"

            return TranscriptionResult(
                text: text,
                language: detectedLanguage,
                audioDuration: audioDuration,
                transcriptionDuration: transcriptionDuration,
                confidence: nil
            )

        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.transcriptionFailed(underlying: error)
        }
    }

    /// Loads an audio file and converts it to a float array at 16kHz.
    private func loadAudioFile(url: URL) async throws -> [Float] {
        return try await Task.detached {
            let audioFile = try AVAudioFile(forReading: url)
            let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(audioFile.length)
            ) else {
                throw TranscriptionError.invalidAudioFile
            }

            // Create a converter if needed
            let processingFormat = audioFile.processingFormat
            if processingFormat.sampleRate != 16000 || processingFormat.channelCount != 1 {
                guard let converter = AVAudioConverter(from: processingFormat, to: format) else {
                    throw TranscriptionError.invalidAudioFile
                }

                let inputBuffer = AVAudioPCMBuffer(
                    pcmFormat: processingFormat,
                    frameCapacity: AVAudioFrameCount(audioFile.length)
                )!
                try audioFile.read(into: inputBuffer)

                var error: NSError?
                converter.convert(to: buffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return inputBuffer
                }

                if let error = error {
                    throw error
                }
            } else {
                try audioFile.read(into: buffer)
            }

            // Convert to float array
            guard let channelData = buffer.floatChannelData?[0] else {
                throw TranscriptionError.invalidAudioFile
            }

            return Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        }.value
    }

    /// Transcribes audio from raw Data (e.g., from IntentFile).
    ///
    /// - Parameters:
    ///   - audioData: Raw audio file data
    ///   - language: Language code (nil for auto-detect)
    /// - Returns: `TranscriptionResult` with the transcribed text
    /// - Throws: `TranscriptionError` if transcription fails
    func transcribe(
        audioData: Data,
        language: String? = TranscriptionConfig.defaultLanguage
    ) async throws -> TranscriptionResult {
        // Write data to temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        do {
            try audioData.write(to: tempURL)
            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }
            return try await transcribe(fileURL: tempURL, language: language)
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.invalidAudioFile
        }
    }

    // MARK: - Combined Record + Transcribe

    /// Records audio from the microphone and transcribes it.
    /// Uses manual stop - caller is responsible for calling `stopRecordingAndTranscribe()`.
    ///
    /// - Returns: The `AudioRecorderService` instance for UI binding
    func startRecording() throws -> AudioRecorderService {
        guard isModelLoaded else {
            throw TranscriptionError.modelNotDownloaded
        }

        try audioRecorder.startRecording()
        return audioRecorder
    }

    /// Stops the current recording and transcribes the captured audio.
    ///
    /// - Parameter language: Language code (nil for auto-detect)
    /// - Returns: `TranscriptionResult` with the transcribed text
    /// - Throws: `TranscriptionError` if transcription fails
    func stopRecordingAndTranscribe(
        language: String? = TranscriptionConfig.defaultLanguage
    ) async throws -> TranscriptionResult {
        let audioBuffer = audioRecorder.stopRecording()

        guard !audioBuffer.isEmpty else {
            throw TranscriptionError.noAudioCaptured
        }

        return try await transcribe(audioBuffer: audioBuffer, language: language)
    }

    /// Cancels the current recording without transcribing.
    func cancelRecording() {
        audioRecorder.cancelRecording()
    }

    /// Records audio with Voice Activity Detection and transcribes.
    /// Used by App Intents where there's no UI for manual stop.
    ///
    /// - Parameter language: Language code (nil for auto-detect)
    /// - Returns: `TranscriptionResult` with the transcribed text
    /// - Throws: `TranscriptionError` if recording or transcription fails
    func recordWithVADAndTranscribe(
        language: String? = TranscriptionConfig.defaultLanguage
    ) async throws -> TranscriptionResult {
        guard isModelLoaded else {
            throw TranscriptionError.modelNotDownloaded
        }

        statusMessage = "Listening..."

        let audioBuffer = try await audioRecorder.recordWithVAD()

        guard !audioBuffer.isEmpty else {
            throw TranscriptionError.noAudioCaptured
        }

        return try await transcribe(audioBuffer: audioBuffer, language: language)
    }

    /// Records audio in background mode with longer silence detection and audio feedback.
    /// Used by background Shortcuts where user needs audio cues and longer pause tolerance.
    ///
    /// - Parameter language: Language code (nil for auto-detect)
    /// - Returns: `TranscriptionResult` with the transcribed text
    /// - Throws: `TranscriptionError` if recording or transcription fails
    func recordInBackgroundAndTranscribe(
        language: String? = TranscriptionConfig.defaultLanguage
    ) async throws -> TranscriptionResult {
        guard isModelLoaded else {
            throw TranscriptionError.modelNotDownloaded
        }

        statusMessage = "Listening (background)..."

        // Use background-specific recording with audio feedback
        let audioBuffer = try await audioRecorder.recordForBackgroundShortcut()

        guard !audioBuffer.isEmpty else {
            throw TranscriptionError.noAudioCaptured
        }

        return try await transcribe(audioBuffer: audioBuffer, language: language)
    }

    // MARK: - Recorder Access

    /// Provides access to the audio recorder for UI binding (audio level, duration).
    var recorder: AudioRecorderService {
        audioRecorder
    }
}
