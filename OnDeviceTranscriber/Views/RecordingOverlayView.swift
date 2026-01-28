//
//  RecordingOverlayView.swift
//  OnDeviceTranscriber
//
//  Minimal recording overlay for Shortcuts integration.
//  Shows briefly while recording, then returns result and dismisses.
//

import SwiftUI
import Combine

/// Minimal overlay view for recording from Shortcuts.
/// Displays recording status and allows tap to stop.
struct RecordingOverlayView: View {
    @ObservedObject var viewModel: RecordingOverlayViewModel

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.stopRecording()
                }

            VStack(spacing: 24) {
                Spacer()

                // Recording indicator
                if viewModel.isRecording {
                    recordingIndicator
                } else if viewModel.isTranscribing {
                    transcribingIndicator
                } else if viewModel.isLoadingModel {
                    loadingModelIndicator
                }

                Spacer()

                // Tap to stop hint
                if viewModel.isRecording {
                    Text("Tap anywhere to stop")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 50)
                }
            }
        }
        .task {
            await viewModel.startRecordingFlow()
        }
    }

    private var recordingIndicator: some View {
        VStack(spacing: 16) {
            // Pulsing circle
            ZStack {
                Circle()
                    .fill(.red.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .scaleEffect(viewModel.pulseScale)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: viewModel.pulseScale
                    )

                Circle()
                    .fill(.red)
                    .frame(width: 80, height: 80)

                Image(systemName: "mic.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            Text("Recording...")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(viewModel.formattedDuration)
                .font(.system(.title, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))

            // Audio level bar
            AudioLevelBar(level: viewModel.audioLevel)
                .frame(width: 200, height: 6)
        }
        .onAppear {
            viewModel.pulseScale = 1.3
        }
    }

    private var transcribingIndicator: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(2)
                .tint(.white)

            Text("Transcribing...")
                .font(.title2.bold())
                .foregroundStyle(.white)
        }
    }

    private var loadingModelIndicator: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(2)
                .tint(.white)

            Text("Loading model...")
                .font(.title2.bold())
                .foregroundStyle(.white)
        }
    }
}

/// Simple audio level bar
struct AudioLevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))

                RoundedRectangle(cornerRadius: 3)
                    .fill(.white)
                    .frame(width: geometry.size.width * CGFloat(level))
                    .animation(.easeOut(duration: 0.1), value: level)
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class RecordingOverlayViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var isLoadingModel = false
    @Published var audioLevel: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var pulseScale: CGFloat = 1.0
    @Published var error: String?

    private let whisperService = WhisperService.shared
    private var recordingTask: Task<Void, Never>?

    /// Completion handler called with transcription result or error
    var onComplete: ((Result<String, Error>) -> Void)?

    /// Language for transcription
    var language: String = "pt"

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func startRecordingFlow() async {
        do {
            // Load model if needed
            if !whisperService.isModelLoaded {
                isLoadingModel = true
                try await whisperService.loadModel()
                isLoadingModel = false
            }

            // Start recording
            isRecording = true

            // Start duration timer
            let startTime = Date()
            let timerTask = Task {
                while !Task.isCancelled && isRecording {
                    try? await Task.sleep(for: .milliseconds(100))
                    recordingDuration = Date().timeIntervalSince(startTime)
                    audioLevel = whisperService.recorder.audioLevel
                }
            }

            // Determine language
            let transcriptionLanguage: String? = language.lowercased() == "auto" ? nil : language

            // Record and transcribe
            let result = try await whisperService.recordInBackgroundAndTranscribe(
                language: transcriptionLanguage
            )

            timerTask.cancel()
            isRecording = false
            isTranscribing = true

            // Small delay to show transcribing state
            try? await Task.sleep(for: .milliseconds(500))

            isTranscribing = false
            onComplete?(.success(result.text))

        } catch {
            isRecording = false
            isTranscribing = false
            isLoadingModel = false
            onComplete?(.failure(error))
        }
    }

    func stopRecording() {
        if isRecording {
            whisperService.cancelRecording()
            // The recordInBackgroundAndTranscribe will handle the cancellation
            // and return whatever was recorded
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RecordingOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingOverlayView(viewModel: RecordingOverlayViewModel())
    }
}
#endif
