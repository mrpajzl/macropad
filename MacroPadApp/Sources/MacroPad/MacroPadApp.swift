import SwiftUI

@main
struct MacroPadApp: App {
    @StateObject private var learningPad = LearningPad()
    @ObservedObject private var mic = MicController.shared

    init() { MicController.shared.registerHotkey(Chord(mods: 0, code: 0x6d)) }

    var body: some Scene {
        Window("MacroPad", id: "main") {
            HardwareWorkspace(pad: learningPad)
        }
        .defaultSize(width: 900, height: 700)

        MenuBarExtra {
            Button(mic.muted ? "Zapnout mikrofon" : "Vypnout mikrofon") { mic.toggle() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Divider()
            Text(learningPad.ready ? "MacroPad · \(learningPad.project.controls.count) prvků" : "MacroPad je odpojený").foregroundStyle(.secondary)
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
