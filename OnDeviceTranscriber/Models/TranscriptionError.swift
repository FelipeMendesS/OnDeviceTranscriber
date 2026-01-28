//
//  TranscriptionError.swift
//  OnDeviceTranscriber
//
//  Custom error types for transcription operations.
//

import Foundation

/// Errors that can occur during transcription operations
enum TranscriptionError: LocalizedError, Sendable {

    // MARK: - Model Errors

    /// Model has not been downloaded yet
    case modelNotDownloaded

    /// Model is currently being downloaded
    case modelDownloadInProgress

    /// Failed to download the model
    case modelDownloadFailed(underlying: Error?)

    /// Failed to load the model into memory
    case modelLoadFailed(underlying: Error?)

    // MARK: - Permission Errors

    /// Microphone permission was denied by the user
    case microphonePermissionDenied

    /// Microphone permission has not been determined yet
    case microphonePermissionNotDetermined

    // MARK: - Recording Errors

    /// Failed to start audio recording
    case recordingStartFailed(underlying: Error?)

    /// Recording was interrupted (e.g., phone call)
    case recordingInterrupted

    /// No audio was captured during recording
    case noAudioCaptured

    // MARK: - Transcription Errors

    /// The audio file could not be read or is invalid
    case invalidAudioFile

    /// No speech was detected in the audio
    case noSpeechDetected

    /// Transcription process failed
    case transcriptionFailed(underlying: Error?)

    /// Operation was cancelled by the user
    case cancelled

    // MARK: - LocalizedError Implementation

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Transcription model not downloaded"
        case .modelDownloadInProgress:
            return "Model download in progress"
        case .modelDownloadFailed:
            return "Failed to download transcription model"
        case .modelLoadFailed:
            return "Failed to load transcription model"
        case .microphonePermissionDenied:
            return "Microphone access denied"
        case .microphonePermissionNotDetermined:
            return "Microphone permission required"
        case .recordingStartFailed:
            return "Could not start recording"
        case .recordingInterrupted:
            return "Recording was interrupted"
        case .noAudioCaptured:
            return "No audio was captured"
        case .invalidAudioFile:
            return "Invalid audio file"
        case .noSpeechDetected:
            return "No speech detected"
        case .transcriptionFailed:
            return "Transcription failed"
        case .cancelled:
            return "Operation cancelled"
        }
    }

    var failureReason: String? {
        switch self {
        case .modelNotDownloaded:
            return "The transcription model needs to be downloaded before use."
        case .modelDownloadInProgress:
            return "Please wait for the model download to complete."
        case .modelDownloadFailed(let error):
            return "Download error: \(error?.localizedDescription ?? "Unknown error")"
        case .modelLoadFailed(let error):
            return "Load error: \(error?.localizedDescription ?? "Unknown error")"
        case .microphonePermissionDenied:
            return "OnDeviceTranscriber needs microphone access to record audio for transcription."
        case .microphonePermissionNotDetermined:
            return "Please grant microphone access when prompted."
        case .recordingStartFailed(let error):
            return "Recording error: \(error?.localizedDescription ?? "Unknown error")"
        case .recordingInterrupted:
            return "The recording was stopped due to an interruption."
        case .noAudioCaptured:
            return "The recording completed but no audio data was captured."
        case .invalidAudioFile:
            return "The provided audio file could not be read or is in an unsupported format."
        case .noSpeechDetected:
            return "The audio was processed but no speech was found."
        case .transcriptionFailed(let error):
            return "Processing error: \(error?.localizedDescription ?? "Unknown error")"
        case .cancelled:
            return "The operation was cancelled by the user."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .modelNotDownloaded, .modelDownloadFailed:
            return "Open the app to download the transcription model."
        case .modelDownloadInProgress:
            return "Wait for the download to complete and try again."
        case .modelLoadFailed:
            return "Try restarting the app. If the problem persists, reinstall the app."
        case .microphonePermissionDenied:
            return "Go to Settings > Privacy & Security > Microphone and enable access for OnDeviceTranscriber."
        case .microphonePermissionNotDetermined:
            return "Tap the record button to trigger the permission request."
        case .recordingStartFailed, .recordingInterrupted:
            return "Check that no other app is using the microphone and try again."
        case .noAudioCaptured:
            return "Ensure your microphone is working and try again."
        case .invalidAudioFile:
            return "Try with a different audio file in a supported format (WAV, M4A, MP3)."
        case .noSpeechDetected:
            return "Speak clearly and ensure you're close to the microphone."
        case .transcriptionFailed:
            return "Please try again. If the problem persists, restart the app."
        case .cancelled:
            return nil
        }
    }

    /// Whether this error should prompt the user to open Settings
    var requiresSettingsAccess: Bool {
        switch self {
        case .microphonePermissionDenied:
            return true
        default:
            return false
        }
    }

    /// Whether this error is recoverable by retrying
    var isRetryable: Bool {
        switch self {
        case .modelDownloadFailed, .modelLoadFailed, .recordingStartFailed,
             .recordingInterrupted, .noAudioCaptured, .transcriptionFailed:
            return true
        default:
            return false
        }
    }
}
