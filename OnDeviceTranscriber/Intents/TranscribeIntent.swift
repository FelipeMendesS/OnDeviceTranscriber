//
//  TranscribeIntent.swift
//  OnDeviceTranscriber
//
//  App Intent for Shortcuts integration.
//  Allows transcription to be triggered from Shortcuts app workflows.
//

import AppIntents
import Foundation
import AVFoundation

/// App Intent that transcribes audio and returns the text.
/// Can be triggered from the Shortcuts app on iOS and macOS.
///
/// Usage in Shortcuts:
/// - "Transcribe Audio" action appears in Shortcuts app
/// - Optional: provide an audio file to transcribe
/// - Optional: specify language (defaults to Portuguese)
/// - Returns: transcribed text as string output
struct TranscribeIntent: AppIntent {

    // MARK: - Intent Metadata

    /// Title shown in Shortcuts app
    static var title: LocalizedStringResource = "Transcribe Audio"

    /// Description shown in Shortcuts app
    static var description = IntentDescription(
        "Records audio from the microphone or transcribes an audio file using on-device Whisper AI.",
        categoryName: "Transcription"
    )

    /// Make this intent available from Shortcuts, Spotlight, and Siri
    static var openAppWhenRun: Bool = false

    // MARK: - Parameters

    /// Optional audio file to transcribe. If not provided, records from microphone.
    @Parameter(
        title: "Audio File",
        description: "An audio file to transcribe. If not provided, the app will record from your microphone.",
        supportedTypeIdentifiers: ["public.audio"],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var audioFile: IntentFile?

    /// Language for transcription. Defaults to Portuguese.
    @Parameter(
        title: "Language",
        description: "Language of the audio. Use 'auto' for automatic detection.",
        default: "pt"
    )
    var language: String

    // MARK: - Perform

    /// Executes the transcription intent.
    /// - Returns: The transcribed text as a string result.
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let service = WhisperService.shared

        // Ensure model is loaded
        if !service.isModelLoaded {
            try await service.loadModel()
        }

        let result: TranscriptionResult

        // Determine language (nil for auto-detect)
        let transcriptionLanguage: String? = language.lowercased() == "auto" ? nil : language

        if let audioFile = audioFile {
            // Transcribe provided audio file
            let data = audioFile.data
            result = try await service.transcribe(
                audioData: data,
                language: transcriptionLanguage
            )
        } else {
            // Record from microphone using VAD
            // First check microphone permission
            let permission = checkMicrophonePermission()

            guard permission == .authorized else {
                throw TranscribeIntentError.microphonePermissionRequired
            }

            result = try await service.recordWithVADAndTranscribe(
                language: transcriptionLanguage
            )
        }

        return .result(value: result.text)
    }
}

// MARK: - Intent Errors

/// Errors specific to the TranscribeIntent
enum TranscribeIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case microphonePermissionRequired
    case modelNotReady
    case transcriptionFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .microphonePermissionRequired:
            return "Microphone permission is required. Please open OnDeviceTranscriber and grant microphone access."
        case .modelNotReady:
            return "Transcription model is not ready. Please open OnDeviceTranscriber to download the model."
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}

// MARK: - Parameter Options

/// Provides predefined language options for the Shortcuts parameter UI
struct LanguageOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        return [
            "pt",      // Portuguese (default)
            "en",      // English
            "es",      // Spanish
            "fr",      // French
            "de",      // German
            "it",      // Italian
            "auto"     // Auto-detect
        ]
    }
}
