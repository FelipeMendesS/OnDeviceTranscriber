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
    case modelNotReady
    case recordingFailed(String)
    case transcriptionError(String)
    case unknownError(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .microphonePermissionRequired:
            return "Microphone permission is required. Please open OnDeviceTranscriber and grant microphone access."
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
