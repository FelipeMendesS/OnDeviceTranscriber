//
//  ContentView.swift
//  OnDeviceTranscriber
//
//  Main view composing the transcription interface.
//

import SwiftUI

/// Main content view for the transcription app.
/// Adapts layout for iOS (compact) and macOS (spacious).
struct ContentView: View {
    @StateObject private var viewModel = TranscriptionViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundGradient
                    .ignoresSafeArea()

                // Main content
                mainContent
            }
            .navigationTitle("Transcriber")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .alert(
                "Error",
                isPresented: $viewModel.showingError,
                presenting: viewModel.currentError
            ) { error in
                alertButtons(for: error)
            } message: { error in
                Text(error.failureReason ?? error.localizedDescription)
            }
        }
        .task {
            await viewModel.loadModel()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 24) {
            // Status area
            statusSection

            Spacer()

            // Result or empty state
            resultSection

            Spacer()

            // Record button and controls
            controlSection
        }
        .padding()
        .frame(maxWidth: 600) // Limit width on larger screens
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        if viewModel.isDownloading {
            downloadProgressView
        } else if viewModel.isRecording {
            recordingStatusView
        } else if viewModel.isTranscribing {
            transcribingStatusView
        } else if !viewModel.isModelLoaded {
            modelNotLoadedView
        }
    }

    private var downloadProgressView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(1.2)

            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.loadProgress > 0 {
                ProgressView(value: viewModel.loadProgress)
                    .frame(width: 200)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var recordingStatusView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 12, height: 12)
                    .opacity(0.8)

                Text("Recording")
                    .font(.headline)
                    .foregroundStyle(.red)
            }

            Text(viewModel.formattedDuration)
                .font(.system(.title, design: .monospaced))
                .foregroundStyle(.primary)

            // Audio level indicator
            AudioLevelIndicator(level: viewModel.audioLevel)
                .frame(height: 4)
                .frame(maxWidth: 200)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var transcribingStatusView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Transcribing...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var modelNotLoadedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)

            Text("Model not loaded")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Retry") {
                viewModel.retry()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Result Section

    @ViewBuilder
    private var resultSection: some View {
        if let result = viewModel.transcriptionResult {
            TranscriptionResultView(
                result: result,
                onCopy: { viewModel.copyResultToClipboard() },
                onClear: { viewModel.clearResult() },
                showingCopyConfirmation: viewModel.showingCopyConfirmation
            )
        } else if !viewModel.isBusy {
            EmptyTranscriptionView()
        }
    }

    // MARK: - Control Section

    private var controlSection: some View {
        VStack(spacing: 16) {
            // Main record button
            RecordButton(
                isRecording: viewModel.isRecording,
                audioLevel: viewModel.audioLevel,
                isDisabled: !viewModel.canRecord
            ) {
                viewModel.toggleRecording()
            }

            // Action label
            Text(viewModel.actionButtonText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Cancel button (visible when recording)
            if viewModel.isRecording {
                Button("Cancel", role: .destructive) {
                    viewModel.cancelRecording()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.05),
                Color.purple.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Alert Buttons

    @ViewBuilder
    private func alertButtons(for error: TranscriptionError) -> some View {
        if error.requiresSettingsAccess {
            Button("Open Settings") {
                viewModel.openSettings()
            }
            Button("Cancel", role: .cancel) {
                viewModel.dismissError()
            }
        } else if error.isRetryable {
            Button("Retry") {
                viewModel.retry()
            }
            Button("Cancel", role: .cancel) {
                viewModel.dismissError()
            }
        } else {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        }
    }
}

// MARK: - Audio Level Indicator

/// Simple horizontal bar showing current audio input level.
struct AudioLevelIndicator: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))

                // Level bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(level))
                    .animation(.easeOut(duration: 0.1), value: level)
            }
        }
    }

    private var levelColor: Color {
        if level > 0.8 {
            return .red
        } else if level > 0.5 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
