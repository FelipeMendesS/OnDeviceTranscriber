# OnDeviceTranscriber

App multiplataforma (iOS + macOS) para transcrição de áudio de alta qualidade usando WhisperKit.

## 🎯 Objetivo
Transcrição on-device com interface minimalista:
- Botão para gravar/transcrever
- Output de texto
- Integração com Shortcuts
- Suporte a português brasileiro

## 🏗️ Estrutura
- **Shared/**: Código compartilhado entre iOS e macOS
  - **Views/**: SwiftUI views
  - **Services/**: Lógica de negócio (WhisperKit)
  - **Intents/**: Integração com Shortcuts
  - **Models/**: Data models
- **iOS/**: Configurações específicas do iOS
- **macOS/**: Configurações específicas do macOS

## 🛠️ Tecnologias
- SwiftUI (100% - zero Storyboards/XIBs)
- WhisperKit (on-device Whisper para Apple Silicon)
- App Intents (Shortcuts)

## 📋 Requisitos
- **iOS**: 17+ (iPhone 13+ recomendado para WhisperKit)
- **macOS**: 14+ (Apple Silicon recomendado)
- Xcode 15+

## 🚀 Desenvolvimento
- Código editado principalmente via Claude Code
- Xcode usado para build, debug e testes em device
- Arquitetura: MVVM com SwiftUI

## 📦 Instalação

### Dependências
- WhisperKit (via Swift Package Manager)

### Setup
1. Clone o repositório
2. Abra `OnDeviceTranscriber.xcodeproj` no Xcode
3. Selecione seu target (iOS ou macOS)
4. Build & Run (Cmd+R)

## 🎨 Design Decisions
- **UI**: Minimalista - botão + texto
- **STT Model**: WhisperKit small/distil-large-v3 (melhor balanço qualidade/velocidade)
- **Multiplatform**: Código compartilhado máximo
- **On-device**: Zero dependência de cloud/APIs externas
