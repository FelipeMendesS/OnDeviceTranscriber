//
//  TranscriptionResultView.swift
//  OnDeviceTranscriber
//
//  Displays transcription results with copy functionality.
//

import SwiftUI

/// Displays the transcription result text with copy and metadata.
struct TranscriptionResultView: View {
    /// The transcription result to display
    let result: TranscriptionResult

    /// Called when user taps copy button
    let onCopy: () -> Void

    /// Called when user taps clear button
    let onClear: () -> Void

    /// Whether to show the copy confirmation
    let showingCopyConfirmation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with actions
            header

            // Transcription text
            textContent

            // Metadata footer
            metadataFooter
        }
        .padding()
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Label("Transcription", systemImage: "text.quote")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()

            // Copy button
            Button(action: onCopy) {
                Label(
                    showingCopyConfirmation ? "Copied!" : "Copy",
                    systemImage: showingCopyConfirmation ? "checkmark" : "doc.on.doc"
                )
                .font(.subheadline)
                .foregroundStyle(showingCopyConfirmation ? .green : .blue)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut, value: showingCopyConfirmation)

            // Clear button
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var textContent: some View {
        ScrollView {
            Text(result.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 300)
    }

    private var metadataFooter: some View {
        HStack(spacing: 16) {
            // Language
            Label(languageDisplayName, systemImage: "globe")

            // Duration
            Label(formattedAudioDuration, systemImage: "waveform")

            // Performance
            Label(performanceText, systemImage: "speedometer")

            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var backgroundStyle: some ShapeStyle {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }

    // MARK: - Computed Display Values

    private var languageDisplayName: String {
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: result.language)?.capitalized ?? result.language.uppercased()
    }

    private var formattedAudioDuration: String {
        let seconds = Int(result.audioDuration)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes)m \(remainingSeconds)s"
        }
    }

    private var performanceText: String {
        let rtf = result.realTimeFactor
        if rtf < 1.0 {
            return String(format: "%.1fx faster", 1.0 / rtf)
        } else {
            return String(format: "%.1fx realtime", rtf)
        }
    }
}

// MARK: - Empty State View

/// Placeholder view when no transcription result exists yet.
struct EmptyTranscriptionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No transcription yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Tap the microphone button to start recording")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct TranscriptionResultView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            TranscriptionResultView(
                result: .sample,
                onCopy: { print("Copy tapped") },
                onClear: { print("Clear tapped") },
                showingCopyConfirmation: false
            )

            TranscriptionResultView(
                result: .sample,
                onCopy: { print("Copy tapped") },
                onClear: { print("Clear tapped") },
                showingCopyConfirmation: true
            )
        }
        .padding()
    }
}

struct EmptyTranscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyTranscriptionView()
    }
}
#endif
