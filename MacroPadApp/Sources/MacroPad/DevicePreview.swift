import SwiftUI

/// A view of the assembled device; the editable 8×8 grid lives in device settings.
struct DevicePreview: View {
    let controls: [HardwareControl]
    let activity: HardwareActivity
    let connected: Bool
    @Binding var selected: Int?

    private var left: Int { controls.map(\.x).min() ?? 0 }
    private var top: Int { controls.map(\.y).min() ?? 0 }
    private var columns: Int { (controls.map(\.x).max() ?? left) - left + 1 }
    private var rows: Int { (controls.map(\.y).max() ?? top) - top + 1 }
    private let pitch: CGFloat = 106

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("VÁŠ MACROPAD").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
                Spacer()
                Text("\(controls.count) prvky").font(.caption).foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: true) {
                    TimelineView(.animation(minimumInterval: 0.05, paused: !connected)) { context in
                        enclosure(at: context.date.timeIntervalSinceReferenceDate, pitch: max(80, min(106, (geometry.size.width - 78) / CGFloat(columns))))
                    }
                    .padding(24)
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                }
            }.frame(height: CGFloat(rows) * pitch + 116)
            HStack(spacing: 7) {
                Circle().fill(connected ? Color.green : Color.secondary).frame(width: 5, height: 5)
                Text(connected ? "Živý náhled · kliknutím vyberte prvek" : "Náhled uloženého rozložení")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.06)))
    }

    private func enclosure(at time: TimeInterval, pitch: CGFloat) -> some View {
        VStack(spacing: 16) {
            HStack {
                screw
                Spacer()
                Text("M A C R O P A D").font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                Spacer()
                screw
            }
            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(controls) { control in
                    let active = activity.isActive(control.id, at: time)
                    let direction = activity.direction(control.id, at: time)
                    Button { selected = control.id } label: {
                        DeviceControl(control: control, selected: selected == control.id, active: active, direction: direction)
                            .frame(width: 92, height: 98)
                            .scaleEffect(pitch / 106)
                    }
                    .buttonStyle(.plain)
                    .frame(width: pitch - 14, height: pitch - 8)
                    .offset(x: CGFloat(control.x - left) * pitch, y: CGFloat(control.y - top) * pitch)
                    .accessibilityLabel(control.title)
                    .accessibilityValue(active ? (direction == 0 ? "Stisknuto" : direction > 0 ? "Doprava" : "Doleva") : "V klidu")
                    .help("\(control.title) · \(control.actions[0].previewTitle)")
                }
            }.frame(width: CGFloat(columns) * pitch - 14, height: CGFloat(rows) * pitch - 8)
        }
        .padding(22)
        .background(LinearGradient(colors: [Color(white: 0.19), Color(white: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 9)
    }
    private var screw: some View {
        Circle().fill(.black.opacity(0.4)).frame(width: 5, height: 5)
            .overlay(Circle().stroke(.white.opacity(0.13), lineWidth: 0.5))
    }
}

private struct DeviceControl: View {
    let control: HardwareControl
    let selected: Bool
    let active: Bool
    let direction: Int
    private var accent: Color { active ? .green : .cyan }
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if control.kind == .encoder {
                    Circle().fill(.black.opacity(0.55)).frame(width: 74, height: 74).offset(y: 3)
                    Circle().fill(LinearGradient(colors: [Color(white: 0.46), Color(white: 0.21)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 70, height: 70)
                        .overlay(Circle().strokeBorder(selected || active ? accent : .white.opacity(0.15), lineWidth: selected || active ? 2 : 1))
                    Circle().stroke(.black.opacity(0.25), lineWidth: 1).frame(width: 59, height: 59)
                    Capsule().fill(selected || active ? accent : .white.opacity(0.75)).frame(width: 3, height: 10).offset(y: -23)
                        .rotationEffect(.degrees(Double(direction) * 25))
                    Image(systemName: direction > 0 ? "arrow.clockwise" : direction < 0 ? "arrow.counterclockwise" : control.actions[0].previewSymbol)
                        .font(.system(size: 19, weight: .medium)).foregroundStyle(active ? accent : .white.opacity(0.9))
                } else {
                    RoundedRectangle(cornerRadius: 13).fill(.black.opacity(0.7)).frame(width: 78, height: 72).offset(y: 4)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [Color(white: selected ? 0.31 : 0.27), Color(white: 0.17)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 78, height: 72)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected || active ? accent : .white.opacity(0.14), lineWidth: selected || active ? 2 : 1))
                    VStack(spacing: 6) {
                        if control.actions[0].kind == .keys, !control.actions[0].chords.isEmpty {
                            Text(control.actions[0].chords[0].label).font(.system(size: 19, weight: .medium)).lineLimit(1).minimumScaleFactor(0.5)
                        } else {
                            Image(systemName: control.actions[0].previewSymbol).font(.system(size: 20, weight: .medium))
                        }
                        Text(control.actions[0].previewTitle).font(.system(size: 9, weight: .medium)).lineLimit(1).minimumScaleFactor(0.6)
                    }.foregroundStyle(active ? accent : .white.opacity(0.92)).padding(8).frame(width: 78)
                }
            }
            .frame(height: 76)
            .offset(y: active && direction == 0 ? 2 : 0)
            Text(control.title).font(.system(size: 9, weight: .medium)).foregroundStyle(selected || active ? accent : .white.opacity(0.45))
        }
        .animation(.easeOut(duration: 0.1), value: active)
        .animation(.easeOut(duration: 0.1), value: selected)
    }
}

private extension MacroDef {
    var previewTitle: String {
        switch kind {
        case .keys: return chords.isEmpty ? "Bez akce" : chords.map(\.label).joined(separator: " → ")
        case .media: return MediaKey.all.first { $0.code == media }?.title ?? "Média"
        case .mouse: return mouse.title
        case .micMute: return "Mikrofon"
        }
    }
    var previewSymbol: String {
        switch kind {
        case .micMute: return "mic.slash"
        case .keys: return chords.isEmpty ? "plus" : "command"
        case .mouse: return "computermouse"
        case .media:
            switch media {
            case 0xe9: return "speaker.plus"
            case 0xea: return "speaker.minus"
            case 0xe2: return "speaker.slash"
            case 0xcd: return "playpause.fill"
            case 0xb5: return "forward.end.fill"
            case 0xb6: return "backward.end.fill"
            case 0xb7: return "stop.fill"
            case 0x6f, 0x70: return "sun.max"
            default: return "music.note"
            }
        }
    }
}
