//
//  RecordButton.swift
//  OnDeviceTranscriber
//
//  Animated record/stop button with audio level visualization.
//

import SwiftUI

/// A large, animated button for starting and stopping audio recording.
/// Shows visual feedback for recording state and audio level.
struct RecordButton: View {
    /// Whether the button is in recording state
    let isRecording: Bool

    /// Current audio level (0.0 to 1.0) for pulse animation
    let audioLevel: Float

    /// Whether the button should be disabled
    let isDisabled: Bool

    /// Action to perform when tapped
    let action: () -> Void

    // MARK: - Animation State

    @State private var isPulsing = false

    // MARK: - Constants

    private let buttonSize: CGFloat = 80
    private let maxPulseScale: CGFloat = 1.5

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulse ring (visible when recording)
                if isRecording {
                    pulseRing
                }

                // Main button circle
                mainButton
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startPulseAnimation()
            } else {
                stopPulseAnimation()
            }
        }
    }

    // MARK: - Subviews

    private var pulseRing: some View {
        Circle()
            .stroke(Color.red.opacity(0.3), lineWidth: 4)
            .frame(width: buttonSize, height: buttonSize)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .animation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
    }

    private var mainButton: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(buttonBackgroundColor)
                .frame(width: buttonSize, height: buttonSize)
                .shadow(color: shadowColor, radius: isRecording ? 10 : 5)

            // Icon
            buttonIcon
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
        }
        .scaleEffect(isRecording ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isRecording)
    }

    @ViewBuilder
    private var buttonIcon: some View {
        if isRecording {
            // Stop icon (square)
            RoundedRectangle(cornerRadius: 4)
                .frame(width: 24, height: 24)
        } else {
            // Microphone icon
            Image(systemName: "mic.fill")
        }
    }

    // MARK: - Computed Properties

    private var buttonBackgroundColor: Color {
        if isDisabled {
            return .gray
        } else if isRecording {
            return .red
        } else {
            return .blue
        }
    }

    private var shadowColor: Color {
        if isRecording {
            return .red.opacity(0.5)
        } else {
            return .blue.opacity(0.3)
        }
    }

    private var pulseScale: CGFloat {
        let baseScale: CGFloat = 1.0
        let levelBoost = CGFloat(audioLevel) * (maxPulseScale - 1.0)
        return isPulsing ? baseScale + levelBoost + 0.2 : baseScale
    }

    private var pulseOpacity: Double {
        isPulsing ? 0.6 : 0.0
    }

    // MARK: - Animation Control

    private func startPulseAnimation() {
        isPulsing = true
    }

    private func stopPulseAnimation() {
        isPulsing = false
    }
}

// MARK: - Preview

#if DEBUG
struct RecordButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            RecordButton(
                isRecording: false,
                audioLevel: 0,
                isDisabled: false
            ) {
                print("Tapped")
            }

            RecordButton(
                isRecording: true,
                audioLevel: 0.5,
                isDisabled: false
            ) {
                print("Tapped")
            }

            RecordButton(
                isRecording: false,
                audioLevel: 0,
                isDisabled: true
            ) {
                print("Tapped")
            }
        }
        .padding()
    }
}
#endif
