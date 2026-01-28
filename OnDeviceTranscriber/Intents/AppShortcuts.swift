//
//  AppShortcuts.swift
//  OnDeviceTranscriber
//
//  Provides suggested shortcuts that appear in the Shortcuts app.
//

import AppIntents

/// Provides app shortcuts that appear in the Shortcuts app and Siri.
struct AppShortcuts: AppShortcutsProvider {

    /// The app shortcuts to provide
    static var appShortcuts: [AppShortcut] {
        // Primary shortcut: Quick transcription from microphone
        AppShortcut(
            intent: TranscribeIntent(),
            phrases: [
                "Transcribe with \(.applicationName)",
                "Start transcription in \(.applicationName)",
                "Record and transcribe with \(.applicationName)",
                "Transcrever com \(.applicationName)",
                "Iniciar transcrição no \(.applicationName)"
            ],
            shortTitle: "Transcribe Audio",
            systemImageName: "mic.fill"
        )
    }
}
