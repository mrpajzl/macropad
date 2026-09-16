import SwiftUI

@main
struct MacroPadApp: App {
    @StateObject private var state = AppState()
    @StateObject private var learningPad = LearningPad()
    @ObservedObject private var mic = MicController.shared

    var body: some Scene {
        Window("MacroPad", id: "main") {
            TabView {
                HardwareWorkspace(pad: learningPad).tabItem { Label("Vlastní MacroPad", systemImage: "square.grid.3x3") }
                ContentView().environmentObject(state).tabItem { Label("Původní konfigurátor", systemImage: "keyboard") }
                    .onDisappear { state.ble.disconnect(); state.recorder.stop() }
            }
        }
        .defaultSize(width: 900, height: 700)

        MenuBarExtra {
            Button(mic.muted ? "Zapnout mikrofon" : "Vypnout mikrofon") { mic.toggle() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Divider()
            Text(learningPad.ready ? "MacroPad · \(learningPad.project.controls.count) prvků" : state.connectionLabel).foregroundStyle(.secondary)
            OpenMainWindowButton()
            Divider()
            Button("Ukončit MacroPad") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Image(systemName: mic.muted ? "mic.slash.fill" : "mic.fill")
        }
    }
}

struct OpenMainWindowButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Otevřít konfigurátor…") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
    }
}
