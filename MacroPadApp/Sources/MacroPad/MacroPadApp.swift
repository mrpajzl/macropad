import SwiftUI

@main
struct MacroPadApp: App {
    @StateObject private var learningPad = LearningPad()
    @ObservedObject private var wheel = ActionWheel.shared
    @ObservedObject private var mic = MicController.shared

    init() { ActionWheel.shared.start(); MicController.shared.registerHotkey(Chord(mods: 0, code: 0x6d)) }

    var body: some Scene {
        Window("MacroPad", id: "main") {
            HardwareWorkspace(pad: learningPad)
                .alert("Kruhové menu", isPresented: Binding(get: { !wheel.error.isEmpty }, set: { if !$0 { wheel.error = "" } })) {
                    Button("OK") { wheel.error = "" }
                } message: { Text(wheel.error) }
        }
        .defaultSize(width: 1100, height: 720)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            Button(mic.muted ? "Zapnout mikrofon" : "Vypnout mikrofon") { mic.toggle() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Button("Náhled přepínání aplikací…") { wheel.show(mode: .applications, control: -1, preview: true) }
            if !wheel.error.isEmpty { Text(wheel.error) }
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
