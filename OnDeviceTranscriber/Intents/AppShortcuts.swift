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
        // Primary shortcut: Background voice recording and transcription
        AppShortcut(
            intent: RecordAndTranscribeIntent(),
            phrases: [
                "Record and transcribe with \(.applicationName)",
                "Start voice transcription in \(.applicationName)",
                "Transcribe my voice with \(.applicationName)",
                "Gravar e transcrever com \(.applicationName)",
                "Iniciar transcrição de voz no \(.applicationName)",
                "Transcrever minha voz com \(.applicationName)"
            ],
            shortTitle: "Record & Transcribe",
            systemImageName: "mic.fill"
        )

        // Secondary shortcut: Transcribe audio file
        AppShortcut(
            intent: TranscribeFileIntent(),
            phrases: [
                "Transcribe audio file with \(.applicationName)",
                "Transcribe file in \(.applicationName)",
                "Transcrever arquivo de áudio com \(.applicationName)",
                "Transcrever arquivo no \(.applicationName)"
            ],
            shortTitle: "Transcribe File",
            systemImageName: "doc.text"
        )
    }
}
