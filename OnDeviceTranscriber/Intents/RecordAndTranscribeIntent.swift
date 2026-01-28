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
import os.log

private let intentLogger = Logger(subsystem: "com.ondevicetranscriber", category: "RecordAndTranscribeIntent")

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
        intentLogger.info("=== RecordAndTranscribeIntent.perform() STARTED ===")

        let service = WhisperService.shared

        // Step 1: Load model if needed
        intentLogger.info("Step 1: Checking model state - isModelLoaded: \(service.isModelLoaded)")
        if !service.isModelLoaded {
            intentLogger.info("Model not loaded, loading now...")
            do {
                try await service.loadModel()
                intentLogger.info("Model loaded successfully")
            } catch {
                intentLogger.error("Model load failed: \(error.localizedDescription)")
                throw RecordAndTranscribeError.modelNotReady(reason: error.localizedDescription)
            }
        }

        // Step 2: Check microphone permission
        intentLogger.info("Step 2: Checking microphone permission")
        let permission = checkMicrophonePermission()
        intentLogger.info("Microphone permission status: \(String(describing: permission.rawValue))")
        guard permission == .authorized else {
            intentLogger.error("Microphone permission not authorized: \(String(describing: permission.rawValue))")
            throw RecordAndTranscribeError.microphonePermissionRequired
        }

        // Step 3: Determine language
        let transcriptionLanguage: String? = language.lowercased() == "auto" ? nil : language
        intentLogger.info("Step 3: Language set to: \(transcriptionLanguage ?? "auto-detect")")

        // Step 4: Record and transcribe
        intentLogger.info("Step 4: Starting recordInBackgroundAndTranscribe...")
        do {
            let result = try await service.recordInBackgroundAndTranscribe(
                language: transcriptionLanguage
            )
            intentLogger.info("=== RecordAndTranscribeIntent.perform() SUCCESS ===")
            intentLogger.info("Transcribed text length: \(result.text.count) characters")
            return .result(value: result.text)
        } catch let error as TranscriptionError {
            intentLogger.error("TranscriptionError: \(error.localizedDescription)")
            throw RecordAndTranscribeError.transcriptionFailed(reason: error.localizedDescription)
        } catch is CancellationError {
            intentLogger.error("CancellationError caught - task was cancelled")
            throw RecordAndTranscribeError.operationCancelled
        } catch {
            intentLogger.error("Unexpected error: \(type(of: error)) - \(error.localizedDescription)")
            // Log full error details for debugging
            intentLogger.error("Full error: \(String(describing: error))")
            throw RecordAndTranscribeError.recordingFailed(reason: error.localizedDescription)
        }
    }
}

// MARK: - Intent Errors

/// Errors specific to the RecordAndTranscribeIntent
enum RecordAndTranscribeError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case microphonePermissionRequired
    case modelNotReady(reason: String)
    case recordingFailed(reason: String)
    case transcriptionFailed(reason: String)
    case operationCancelled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .microphonePermissionRequired:
            return "Microphone permission is required. Please open OnDeviceTranscriber and grant microphone access."
        case .modelNotReady(let reason):
            return "Transcription model is not ready: \(reason). Please open OnDeviceTranscriber to download the model."
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .transcriptionFailed(let reason):
            return "Transcription error: \(reason)"
        case .operationCancelled:
            return "Operation was cancelled. This may happen if the Shortcut times out. Try again or use the app directly for longer recordings."
        }
    }
}
