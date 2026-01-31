//
//  RecordAndTranscribeIntent.swift
//  OnDeviceTranscriber
//
//  App Intent for Shortcuts integration.
//  Opens minimal recording overlay, records, transcribes, and returns text.
//

import AppIntents
import Foundation
import AVFoundation
import os.log

private let intentLogger = Logger(subsystem: "com.ondevicetranscriber", category: "RecordAndTranscribeIntent")
import SwiftUI
import Combine

/// App Intent that opens a minimal recording overlay and returns transcribed text.
/// Triggered from Shortcuts, opens briefly for recording then returns to previous app.
struct RecordAndTranscribeIntent: AppIntent {

    // MARK: - Intent Metadata

    static var title: LocalizedStringResource = "Record & Transcribe"

    static var description = IntentDescription(
        "Opens a minimal recording overlay. Speak, then tap to stop or wait for silence. Returns transcribed text.",
        categoryName: "Transcription"
    )

    /// Open app to show recording overlay
    static var openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(
        title: "Language",
        description: "Language of the audio. Use 'auto' for automatic detection.",
        default: "pt"
    )
    var language: String

    // MARK: - Perform

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
        // Signal that we're launching from shortcut
        IntentLaunchState.shared.isLaunchedFromIntent = true
        IntentLaunchState.shared.language = language

        // Wait for the recording to complete
        let result = await withCheckedContinuation { continuation in
            IntentLaunchState.shared.continuation = continuation
        }

        // Reset state
        IntentLaunchState.shared.isLaunchedFromIntent = false
        IntentLaunchState.shared.continuation = nil

        switch result {
        case .success(let text):
            return .result(value: text)
        case .failure(let error):
            if let transcriptionError = error as? TranscriptionError {
                throw RecordAndTranscribeError.transcriptionError(
                    transcriptionError.errorDescription ?? "Recording failed"
                )
            } else {
                throw RecordAndTranscribeError.unknownError(error.localizedDescription)
            }
        }
    }
}

// MARK: - Shared State for Intent Communication

@MainActor
final class IntentLaunchState: ObservableObject {
    static let shared = IntentLaunchState()

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
    @Published var isLaunchedFromIntent = false
    var language: String = "pt"
    var continuation: CheckedContinuation<Result<String, Error>, Never>?

    private init() {}

    func completeWithResult(_ result: Result<String, Error>) {
        continuation?.resume(returning: result)
    }
}

// MARK: - Intent Errors

enum RecordAndTranscribeError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case microphonePermissionRequired
    case modelNotReady(reason: String)
    case recordingFailed(reason: String)
    case transcriptionFailed(reason: String)
    case operationCancelled
    case modelNotReady
    case recordingFailed(String)
    case transcriptionError(String)
    case unknownError(String)

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
        case .modelNotReady:
            return "Transcription model is not ready. Please open OnDeviceTranscriber to download the model first."
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .transcriptionError(let message):
            return "Transcription error: \(message)"
        case .unknownError(let message):
            return "Error: \(message)"
        }
    }
}
