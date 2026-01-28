//
//  TranscriptionViewModel.swift
//  OnDeviceTranscriber
//
//  Main ViewModel for the transcription UI.
//  Coordinates between WhisperService, AudioRecorderService, and SwiftUI views.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

/// Main ViewModel for the transcription interface.
/// Observes WhisperService and AudioRecorderService state and exposes it to views.
@MainActor
final class TranscriptionViewModel: ObservableObject {

    // MARK: - Services

    private let whisperService = WhisperService.shared

    // MARK: - Published UI State

    /// The current transcription result (nil if none yet)
    @Published private(set) var transcriptionResult: TranscriptionResult?

    /// Current error to display (nil if no error)
    @Published var currentError: TranscriptionError?

    /// Whether to show the error alert
    @Published var showingError = false

    /// Whether the copy confirmation should be shown
    @Published var showingCopyConfirmation = false

    // MARK: - Computed Properties (Forwarded from Services)

    /// Whether the model is loaded and ready
    var isModelLoaded: Bool {
        whisperService.isModelLoaded
    }

    /// Whether the model is currently downloading
    var isDownloading: Bool {
        whisperService.isDownloading
    }

    /// Model download/load progress (0.0 to 1.0)
    var loadProgress: Float {
        whisperService.loadProgress
    }

    /// Current status message from the service
    var statusMessage: String {
        whisperService.statusMessage
    }

    /// Whether transcription is in progress
    var isTranscribing: Bool {
        whisperService.isTranscribing
    }

    /// Whether recording is in progress
    var isRecording: Bool {
        whisperService.recorder.isRecording
    }

    /// Current audio level for visualization (0.0 to 1.0)
    var audioLevel: Float {
        whisperService.recorder.audioLevel
    }

    /// Current recording duration in seconds
    var recordingDuration: TimeInterval {
        whisperService.recorder.recordingDuration
    }

    /// Formatted recording duration string (MM:SS)
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Whether any operation is in progress (recording or transcribing)
    var isBusy: Bool {
        isRecording || isTranscribing || isDownloading
    }

    /// Whether the record button should be enabled
    var canRecord: Bool {
        isModelLoaded && !isTranscribing && !isDownloading
    }

    /// Display text for the main action button
    var actionButtonText: String {
        if isDownloading {
            return "Downloading Model..."
        } else if !isModelLoaded {
            return "Load Model"
        } else if isRecording {
            return "Stop Recording"
        } else if isTranscribing {
            return "Transcribing..."
        } else {
            return "Start Recording"
        }
    }

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupObservers()
    }

    private func setupObservers() {
        // Observe WhisperService changes to trigger view updates
        whisperService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Observe AudioRecorderService changes
        whisperService.recorder.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// Loads the transcription model. Call this on app launch.
    func loadModel() async {
        do {
            try await whisperService.loadModel()
        } catch let error as TranscriptionError {
            handleError(error)
        } catch {
            handleError(.modelLoadFailed(underlying: error))
        }
    }

    /// Toggles recording state. Starts recording if stopped, stops and transcribes if recording.
    func toggleRecording() {
        if isRecording {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }

    /// Starts audio recording.
    func startRecording() {
        // Check microphone permission first
        let permission = checkMicrophonePermission()

        switch permission {
        case .authorized:
            do {
                _ = try whisperService.startRecording()
            } catch let error as TranscriptionError {
                handleError(error)
            } catch {
                handleError(.recordingStartFailed(underlying: error))
            }

        case .notDetermined:
            // Request permission
            Task {
                let granted = await requestMicrophonePermission()
                if granted {
                    startRecording() // Retry after permission granted
                } else {
                    handleError(.microphonePermissionDenied)
                }
            }

        case .denied, .restricted:
            handleError(.microphonePermissionDenied)

        @unknown default:
            handleError(.microphonePermissionDenied)
        }
    }

    /// Stops recording and begins transcription.
    func stopRecordingAndTranscribe() {
        Task {
            do {
                let result = try await whisperService.stopRecordingAndTranscribe()
                transcriptionResult = result
            } catch let error as TranscriptionError {
                handleError(error)
            } catch {
                handleError(.transcriptionFailed(underlying: error))
            }
        }
    }

    /// Cancels the current recording without transcribing.
    func cancelRecording() {
        whisperService.cancelRecording()
    }

    /// Copies the transcription text to the clipboard.
    func copyResultToClipboard() {
        guard let text = transcriptionResult?.text else { return }
        copyToClipboard(text)
        showingCopyConfirmation = true

        // Hide confirmation after delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            showingCopyConfirmation = false
        }
    }

    /// Clears the current transcription result.
    func clearResult() {
        transcriptionResult = nil
    }

    /// Opens system settings for microphone permission.
    func openSettings() {
        openAppSettings()
    }

    /// Retries the last failed operation.
    func retry() {
        currentError = nil
        showingError = false

        if !isModelLoaded {
            Task {
                await loadModel()
            }
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: TranscriptionError) {
        currentError = error
        showingError = true
    }

    /// Dismisses the current error.
    func dismissError() {
        currentError = nil
        showingError = false
    }
}

// MARK: - Transcription from File (for future use)

extension TranscriptionViewModel {
    /// Transcribes an audio file at the given URL.
    /// - Parameter url: URL to the audio file
    func transcribeFile(at url: URL) async {
        do {
            let result = try await whisperService.transcribe(fileURL: url)
            transcriptionResult = result
        } catch let error as TranscriptionError {
            handleError(error)
        } catch {
            handleError(.transcriptionFailed(underlying: error))
        }
    }

    /// Transcribes audio from raw data.
    /// - Parameter data: Audio file data
    func transcribeData(_ data: Data) async {
        do {
            let result = try await whisperService.transcribe(audioData: data)
            transcriptionResult = result
        } catch let error as TranscriptionError {
            handleError(error)
        } catch {
            handleError(.transcriptionFailed(underlying: error))
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension TranscriptionViewModel {
    /// Creates a ViewModel with sample data for previews.
    static var preview: TranscriptionViewModel {
        let vm = TranscriptionViewModel()
        vm.transcriptionResult = .sample
        return vm
    }

    /// Creates a ViewModel in error state for previews.
    static var previewWithError: TranscriptionViewModel {
        let vm = TranscriptionViewModel()
        vm.currentError = .microphonePermissionDenied
        vm.showingError = true
        return vm
    }
}
#endif
