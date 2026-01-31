//
//  OnDeviceTranscriberApp.swift
//  OnDeviceTranscriber
//
//  Created by Felipe Mendes dos Santos on 28/01/26.
//

import SwiftUI

@main
struct OnDeviceTranscriberApp: App {
    @StateObject private var intentState = IntentLaunchState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(intentState)
        }
    }
}

// MARK: - Root View

/// Root view that switches between main content and recording overlay based on launch state.
struct RootView: View {
    @EnvironmentObject var intentState: IntentLaunchState

    var body: some View {
        ZStack {
            // Always show ContentView as the base
            ContentView()

            // Overlay recording view when launched from intent
            if intentState.isLaunchedFromIntent {
                RecordingOverlayView(viewModel: makeOverlayViewModel())
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: intentState.isLaunchedFromIntent)
    }

    private func makeOverlayViewModel() -> RecordingOverlayViewModel {
        let viewModel = RecordingOverlayViewModel()
        viewModel.language = intentState.language

        viewModel.onComplete = { result in
            intentState.completeWithResult(result)

            // Dismiss back to previous app after a short delay
            #if os(iOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Suspend the app to return to the previous app
                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
            }
            #endif
        }

        return viewModel
    }
}
