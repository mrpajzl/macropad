import SwiftUI

@main
struct MacroPadApp: App {
    @StateObject private var state = AppState()
    @ObservedObject private var mic = MicController.shared

    var body: some Scene {
        Window("MacroPad", id: "main") {
            ContentView().environmentObject(state)
        }
        .defaultSize(width: 900, height: 700)

        MenuBarExtra {
            Button(mic.muted ? "Zapnout mikrofon" : "Vypnout mikrofon") { mic.toggle() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Divider()
            Text(state.connected ? "CH552 pad připojen" : "CH552 konfigurátor: pad nepřipojen").foregroundStyle(.secondary)
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
