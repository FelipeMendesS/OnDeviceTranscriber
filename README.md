# OnDeviceTranscriber

Multiplatform app (iOS + macOS) for high-quality audio transcription using WhisperKit.

## 🎯 Objective
On-device transcription with minimalist interface:
- Record/transcribe button
- Text output
- Shortcuts integration
- Portuguese Brazilian support (with multilingual capability)

## 🏗️ Structure
- **Shared/**: Code shared between iOS and macOS
  - **Views/**: SwiftUI views
  - **Services/**: Business logic (WhisperKit)
  - **Intents/**: Shortcuts integration
  - **Models/**: Data models
- **iOS/**: iOS-specific configurations
- **macOS/**: macOS-specific configurations

## 🛠️ Technologies
- SwiftUI (100% - zero Storyboards/XIBs)
- WhisperKit (on-device Whisper for Apple Silicon)
- App Intents (Shortcuts)

## 📋 Requirements
- **iOS**: 17+ (iPhone 13+ recommended for WhisperKit)
- **macOS**: 14+ (Apple Silicon recommended)
- Xcode 15+

## 🚀 Development
- Code primarily edited via Claude Code
- Xcode used for build, debug, and device testing
- Architecture: MVVM with SwiftUI

## 📦 Installation

### Dependencies
- WhisperKit (via Swift Package Manager)

### Setup
1. Clone the repository
2. Open `OnDeviceTranscriber.xcodeproj` in Xcode
3. Select your target (iOS or macOS)
4. Build & Run (Cmd+R)

## 🎨 Design Decisions
- **UI**: Minimalist - button + text
- **STT Model**: WhisperKit small/distil-large-v3 (best quality/speed balance)
- **Multiplatform**: Maximum shared code
- **On-device**: Zero cloud/external API dependencies

## 🌍 Language Support
- Primary: Portuguese Brazilian
- Supports 90+ languages via Whisper multilingual models
- On-device means complete privacy

## 📝 License
MIT License

## 👨‍💻 Author
Felipe Mendes dos Santos
