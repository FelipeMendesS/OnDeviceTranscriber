//
//  PlatformHelpers.swift
//  OnDeviceTranscriber
//
//  Platform-specific utilities and conditional compilation helpers.
//

import Foundation
import AVFoundation

// MARK: - Platform Detection

/// Utilities for platform-specific behavior
enum Platform {
    /// True if running on iOS/iPadOS
    static var isIOS: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    /// True if running on macOS
    static var isMacOS: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    /// Human-readable platform name
    static var name: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #else
        return "Unknown"
        #endif
    }
}

// MARK: - Audio Session Configuration

/// Configures the audio session for recording (iOS only)
/// On macOS, this is a no-op as audio sessions are not required.
/// - Parameter forBackground: If true, configures for background Shortcut recording
func configureAudioSession(forBackground: Bool = false) throws {
    #if os(iOS)
    let session = AVAudioSession.sharedInstance()

    if forBackground {
        // For background Shortcuts: use record category with mixWithOthers
        // This allows recording without interrupting other audio
        try session.setCategory(
            .record,
            mode: .default,
            options: [.mixWithOthers, .allowBluetooth]
        )
    } else {
        // For in-app UI: use playAndRecord for future playback features
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
        )
    }

    // Activate the session with options to allow background operation
    try session.setActive(true, options: [])
    #endif
}

/// Configures audio session specifically for background recording
/// Uses record-only category that works better with background intents
func configureAudioSessionForBackground() throws {
    #if os(iOS)
    let session = AVAudioSession.sharedInstance()

    // Use record category - more reliable for background operation
    try session.setCategory(
        .record,
        mode: .default,
        options: [.mixWithOthers, .allowBluetooth]
    )

    // Activate with no special options
    try session.setActive(true, options: [])
    #endif
}

/// Deactivates the audio session (iOS only)
/// Call this when recording is complete to allow other apps to use audio.
func deactivateAudioSession() {
    #if os(iOS)
    do {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
        // Non-fatal: log but don't throw
        print("Failed to deactivate audio session: \(error.localizedDescription)")
    }
    #endif
}

// MARK: - Microphone Permission

/// Checks the current microphone authorization status
func checkMicrophonePermission() -> AVAuthorizationStatus {
    AVCaptureDevice.authorizationStatus(for: .audio)
}

/// Requests microphone permission asynchronously
/// - Returns: True if permission was granted, false otherwise
func requestMicrophonePermission() async -> Bool {
    await withCheckedContinuation { continuation in
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            continuation.resume(returning: granted)
        }
    }
}

// MARK: - Settings URL

/// Opens the app's settings page where the user can grant permissions
func openAppSettings() {
    #if os(iOS)
    if let url = URL(string: UIApplication.openSettingsURLString) {
        Task { @MainActor in
            UIApplication.shared.open(url)
        }
    }
    #elseif os(macOS)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
        NSWorkspace.shared.open(url)
    }
    #endif
}

// MARK: - Clipboard

/// Copies text to the system clipboard
/// - Parameter text: The text to copy
func copyToClipboard(_ text: String) {
    #if os(iOS)
    UIPasteboard.general.string = text
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
}

// MARK: - App Lifecycle Imports

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
