//
//  TranscriptionResult.swift
//  OnDeviceTranscriber
//
//  Data model representing the output of a transcription operation.
//

import Foundation

/// Represents the result of a successful transcription operation.
struct TranscriptionResult: Identifiable, Codable, Sendable {
    /// Unique identifier for this transcription
    let id: UUID

    /// The transcribed text content
    let text: String

    /// Detected or specified language code (e.g., "pt", "en")
    let language: String

    /// Duration of the audio that was transcribed, in seconds
    let audioDuration: TimeInterval

    /// Time taken to perform the transcription, in seconds
    let transcriptionDuration: TimeInterval

    /// Timestamp when the transcription was completed
    let timestamp: Date

    /// Optional confidence score (0.0 to 1.0) if provided by WhisperKit
    let confidence: Float?

    /// Creates a new TranscriptionResult
    /// - Parameters:
    ///   - text: The transcribed text
    ///   - language: Language code of the transcription
    ///   - audioDuration: Duration of the source audio in seconds
    ///   - transcriptionDuration: Time taken to transcribe in seconds
    ///   - confidence: Optional confidence score
    init(
        text: String,
        language: String,
        audioDuration: TimeInterval,
        transcriptionDuration: TimeInterval,
        confidence: Float? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.language = language
        self.audioDuration = audioDuration
        self.transcriptionDuration = transcriptionDuration
        self.timestamp = Date()
        self.confidence = confidence
    }

    /// Convenience property to check if the transcription contains meaningful content
    var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Real-time factor: values < 1.0 mean faster than real-time
    var realTimeFactor: Double {
        guard audioDuration > 0 else { return 0 }
        return transcriptionDuration / audioDuration
    }
}

// MARK: - Preview/Testing Support

extension TranscriptionResult {
    /// Sample result for SwiftUI previews and testing
    static let sample = TranscriptionResult(
        text: "Olá, este é um teste de transcrição usando o WhisperKit no dispositivo.",
        language: "pt",
        audioDuration: 5.2,
        transcriptionDuration: 1.8,
        confidence: 0.95
    )

    /// Empty result for edge case testing
    static let empty = TranscriptionResult(
        text: "",
        language: "pt",
        audioDuration: 2.0,
        transcriptionDuration: 0.5,
        confidence: nil
    )
}
