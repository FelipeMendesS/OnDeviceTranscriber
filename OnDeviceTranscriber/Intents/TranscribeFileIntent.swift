//
//  TranscribeFileIntent.swift
//  OnDeviceTranscriber
//
//  App Intent for transcribing audio files via Shortcuts.
//  Takes an audio file as input and returns transcribed text.
//

import AppIntents
import Foundation

/// App Intent that transcribes an audio file and returns the text.
/// Can be triggered from the Shortcuts app on iOS and macOS.
///
/// Usage in Shortcuts:
/// - "Transcribe Audio File" action appears in Shortcuts app
/// - Provide an audio file to transcribe
/// - Optional: specify language (defaults to Portuguese)
/// - Returns: transcribed text as string output
struct TranscribeFileIntent: AppIntent {

    // MARK: - Intent Metadata

    /// Title shown in Shortcuts app
    static var title: LocalizedStringResource = "Transcribe Audio File"

    /// Description shown in Shortcuts app
    static var description = IntentDescription(
        "Transcribes an audio file using on-device Whisper AI and returns the text.",
        categoryName: "Transcription"
    )

    /// Run in background - don't need to open the app
    static var openAppWhenRun: Bool = false

    // MARK: - Parameters

    /// Audio file to transcribe (required)
    @Parameter(
        title: "Audio File",
        description: "The audio file to transcribe (WAV, M4A, MP3, etc.)",
        supportedTypeIdentifiers: ["public.audio"],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var audioFile: IntentFile

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

        // Determine language (nil for auto-detect)
        let transcriptionLanguage: String? = language.lowercased() == "auto" ? nil : language

        // Transcribe the audio file
        let data = audioFile.data
        let result = try await service.transcribe(
            audioData: data,
            language: transcriptionLanguage
        )

        return .result(value: result.text)
    }
}

// MARK: - Intent Errors

/// Errors specific to the TranscribeFileIntent
enum TranscribeFileIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case invalidAudioFile
    case modelNotReady
    case transcriptionFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidAudioFile:
            return "The provided audio file could not be read or is in an unsupported format."
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
