//
//  RecordAndTranscribeIntent.swift
//  OnDeviceTranscriber
//
//  Background App Intent for Shortcuts integration.
//  Records audio from microphone with VAD, transcribes, and returns text.
//  Runs entirely in background - user stays in their current app.
//

import AppIntents
import Foundation
import AVFoundation

/// App Intent that records audio in background and returns transcribed text.
/// Triggered from Shortcuts, runs without opening app UI.
///
/// Features:
/// - Runs 100% in background (user stays in current app)
/// - Audio/haptic feedback when recording starts and stops
/// - Automatic stop after 5 seconds of silence
/// - Returns transcribed text to Shortcuts for chaining
///
/// Usage in Shortcuts:
/// - "Record & Transcribe" action appears in Shortcuts app
/// - Trigger via Action Button, Siri, or widget
/// - Speak naturally, pause for 5 seconds when done
/// - Transcribed text flows to next Shortcut action
struct RecordAndTranscribeIntent: AppIntent {

    // MARK: - Intent Metadata

    /// Title shown in Shortcuts app
    static var title: LocalizedStringResource = "Record & Transcribe"

    /// Description shown in Shortcuts app
    static var description = IntentDescription(
        "Records audio from microphone in background, automatically stops after 5 seconds of silence, and returns transcribed text. You'll hear a sound when recording starts and stops.",
        categoryName: "Transcription"
    )

    /// Run entirely in background - don't open the app
    static var openAppWhenRun: Bool = false

    // MARK: - Parameters

    /// Language for transcription. Defaults to Portuguese.
    @Parameter(
        title: "Language",
        description: "Language of the audio. Use 'auto' for automatic detection.",
        default: "pt"
    )
    var language: String

    // MARK: - Perform

    /// Executes the recording and transcription intent.
    /// - Returns: The transcribed text as a string result.
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let service = WhisperService.shared

        // Ensure model is loaded
        if !service.isModelLoaded {
            try await service.loadModel()
        }

        // Check microphone permission
        let permission = checkMicrophonePermission()
        guard permission == .authorized else {
            throw RecordAndTranscribeError.microphonePermissionRequired
        }

        // Determine language (nil for auto-detect)
        let transcriptionLanguage: String? = language.lowercased() == "auto" ? nil : language

        // Record with background settings (5s silence, audio feedback)
        let result = try await service.recordInBackgroundAndTranscribe(
            language: transcriptionLanguage
        )

        return .result(value: result.text)
    }
}

// MARK: - Intent Errors

/// Errors specific to the RecordAndTranscribeIntent
enum RecordAndTranscribeError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case microphonePermissionRequired
    case modelNotReady
    case recordingFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .microphonePermissionRequired:
            return "Microphone permission is required. Please open OnDeviceTranscriber and grant microphone access."
        case .modelNotReady:
            return "Transcription model is not ready. Please open OnDeviceTranscriber to download the model."
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        }
    }
}
