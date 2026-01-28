# OnDeviceTranscriber Architecture

> Last updated: January 2025

## Project Overview

OnDeviceTranscriber is a minimalist multiplatform (iOS + macOS) audio transcription app with **Shortcuts integration as a core feature**. It uses WhisperKit for on-device transcription with excellent Portuguese Brazilian accuracy.

### Why This Project Exists

Apple's native Speech Framework has poor accuracy for Portuguese (~8% WER vs ~1-2% WER for Whisper). WhisperKit brings OpenAI's Whisper models to run directly on Apple Silicon.

---

## Configuration Constants

These values are defined in `Services/WhisperService.swift` and can be easily adjusted:

```swift
enum TranscriptionConfig {
    // Voice Activity Detection (VAD) - for Shortcuts recording
    static let silenceThreshold: Float = 0.01          // Audio level considered "silence"
    static let silenceDurationToStop: TimeInterval = 3.0  // Seconds of silence before auto-stop
    static let maxRecordingDuration: TimeInterval = 300   // 5 minutes max

    // Model settings
    static let defaultModel = "small"                  // Options: tiny, small, distil-large-v3
    static let defaultLanguage = "pt"                  // Portuguese Brazilian

    // Audio settings
    static let sampleRate: Int = 16000                 // WhisperKit expects 16kHz
}
```

**To iterate on VAD behavior:** Adjust `silenceDurationToStop` (currently 3 seconds).

---

## Architectural Decisions

### 1. Service Layer: Singleton Pattern

**Decision:** `WhisperService` uses a shared singleton instance.

**Rationale:**
- WhisperKit model loading is expensive (~500MB+ memory, several seconds)
- Both the app UI and App Intents need access to the same loaded model
- Singleton ensures model loads once, reused everywhere
- Prevents duplicate memory usage

```swift
@MainActor
final class WhisperService: ObservableObject {
    static let shared = WhisperService()
    // ...
}
```

### 2. Recording Modes

| Context | Mode | Behavior |
|---------|------|----------|
| **In-App UI** | Manual | User taps Record → speaks → taps Stop. No time limit. |
| **Shortcuts** | VAD + Timeout | Records until 3s of silence detected, max 5 minutes. |

**Rationale:** Shortcuts have no UI for user interaction, so automatic stop detection is required.

### 3. Model Download Strategy

**Decision:** Force download on first app launch with progress UI.

**Rationale:**
- Ensures model is ready when user first tries to transcribe
- Prevents frustrating delays during actual usage
- App Intents can assume model is available (with fallback check)

**Implementation:**
- `OnDeviceTranscriberApp.swift` checks if model exists on launch
- Shows blocking download progress view if not downloaded
- Stores model in app container (persists across launches)

### 4. Default Language

**Decision:** Default to Portuguese Brazilian (`pt`).

**Rationale:** Primary use case is Portuguese transcription. Auto-detect available as option.

### 5. Platform Handling

**Decision:** Single target with conditional compilation.

| Aspect | iOS | macOS |
|--------|-----|-------|
| Audio Session | `AVAudioSession` configuration required | Not needed |
| Permissions | Runtime request dialogs | Sandbox entitlements |
| UI Layout | Compact, touch-optimized | Larger, click-optimized |

```swift
#if os(iOS)
// iOS-specific code
#elseif os(macOS)
// macOS-specific code
#endif
```

### 6. App Intent Architecture

**Decision:** Intent uses `WhisperService.shared` directly.

```
Shortcuts App                    OnDeviceTranscriber
     │                                   │
     ▼                                   ▼
┌──────────┐    invoke    ┌──────────────────────┐
│ Shortcut │ ──────────▶  │   TranscribeIntent   │
└──────────┘              │                      │
                          │  1. Check model      │
                          │  2. Record/load audio│
                          │  3. Transcribe       │
                          │  4. Return text      │
                          └──────────┬───────────┘
                                     │
                                     ▼
                          ┌──────────────────────┐
                          │ WhisperService.shared│
                          │                      │
                          │  - Already loaded    │
                          │  - Same instance as  │
                          │    app UI uses       │
                          └──────────────────────┘
```

**Benefits:**
- If user opens app first, model is pre-loaded for Intent
- No duplicate model loading
- Consistent transcription settings

---

## Project Structure

```
OnDeviceTranscriber/
├── OnDeviceTranscriber.xcodeproj/
├── OnDeviceTranscriber/
│   ├── App/
│   │   └── OnDeviceTranscriberApp.swift     # App entry point, model download check
│   ├── Views/
│   │   ├── ContentView.swift                # Main transcription screen
│   │   ├── RecordButton.swift               # Animated record/stop button
│   │   └── TranscriptionResultView.swift    # Text display with copy
│   ├── ViewModels/
│   │   └── TranscriptionViewModel.swift     # UI state management
│   ├── Services/
│   │   ├── WhisperService.swift             # Core: WhisperKit + recording
│   │   └── AudioRecorderService.swift       # AVAudioEngine wrapper
│   ├── Models/
│   │   ├── TranscriptionResult.swift        # Transcription output model
│   │   └── TranscriptionError.swift         # Custom error types
│   ├── Intents/
│   │   ├── TranscribeIntent.swift           # AppIntent for Shortcuts
│   │   └── AppShortcuts.swift               # Suggested shortcuts
│   ├── Utilities/
│   │   └── PlatformHelpers.swift            # Platform-specific helpers
│   └── Assets.xcassets/
├── ARCHITECTURE.md                          # This file
└── README.md
```

---

## Data Flow

### In-App Transcription Flow

```
User taps Record
       │
       ▼
┌─────────────────┐
│ViewModel starts │
│ AudioRecorder   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     User taps Stop
│ Recording...    │ ◀────────────────────┐
│ (accumulating   │                      │
│  audio buffer)  │──────────────────────┘
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ WhisperService  │
│ .transcribe()   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ TranscriptionResult │
│ displayed in UI │
└─────────────────┘
```

### Shortcuts Transcription Flow

```
Shortcut triggered (Siri, widget, etc.)
       │
       ▼
┌─────────────────────┐
│ TranscribeIntent    │
│ .perform()          │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ Audio file provided?│
└────────┬────────────┘
         │
    ┌────┴────┐
    │ Yes     │ No
    ▼         ▼
┌────────┐  ┌─────────────────┐
│ Use    │  │ Start recording │
│ file   │  │ with VAD        │
└───┬────┘  └────────┬────────┘
    │                │
    │       ┌────────▼────────┐
    │       │ Wait for 3s     │
    │       │ silence or 5min │
    │       └────────┬────────┘
    │                │
    └───────┬────────┘
            │
            ▼
┌─────────────────────┐
│ WhisperService      │
│ .transcribe()       │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ Return text to      │
│ Shortcuts           │
└─────────────────────┘
```

---

## Error Handling Strategy

| Error Type | User Message | Recovery |
|------------|--------------|----------|
| Model not downloaded | "Downloading transcription model..." | Auto-download with progress |
| Microphone permission denied | "Microphone access required" | Open Settings button |
| Recording failed | "Could not access microphone" | Retry button |
| Transcription failed | "Transcription failed. Please try again." | Retry button |
| No speech detected | "No speech detected in audio" | Informational, allow retry |

---

## Future Enhancements (Not in v1.0)

- [ ] Model selection UI (tiny/small/distil-large-v3)
- [ ] Language selection UI
- [ ] Real-time streaming transcription
- [ ] Audio waveform visualization
- [ ] Transcription history
- [ ] Export options (text file, share sheet)
- [ ] Widget for quick recording

---

## Technical Constraints

| Constraint | Value | Rationale |
|------------|-------|-----------|
| Min iOS | 26.0 | Latest platform features |
| Min macOS | 15.7 | Apple Silicon optimized |
| Model size | < 750MB | Balance accuracy vs storage |
| Memory | < 2GB runtime | Fit on 6GB devices |
| Transcription speed | < 2x realtime | Acceptable UX |

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| WhisperKit | main branch | On-device Whisper inference |
| swift-transformers | 1.1.6 | ML model support |
| swift-collections | 1.3.0 | Data structures |

---

## Testing Checklist

### App UI
- [ ] First launch shows model download progress
- [ ] Record button shows visual feedback
- [ ] Transcription appears after recording
- [ ] Copy button works
- [ ] Works on iOS and macOS

### Shortcuts Integration
- [ ] "Transcribe Audio" appears in Shortcuts app
- [ ] Recording from microphone works
- [ ] Audio file input works
- [ ] Text output chains to next action
- [ ] Works on iOS and macOS

### Edge Cases
- [ ] No speech in recording → appropriate message
- [ ] Very long recording (5+ min) → handled gracefully
- [ ] Permission denied → clear error message
- [ ] Model not ready → blocks with feedback
