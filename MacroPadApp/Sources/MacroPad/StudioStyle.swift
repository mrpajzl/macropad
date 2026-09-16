import SwiftUI

enum Studio {
    static let accent = Color(red: 0.36, green: 0.85, blue: 0.94)
    static let background = Color(red: 0.065, green: 0.073, blue: 0.085)
    static let surface = Color(red: 0.105, green: 0.116, blue: 0.13)
    static let border = Color.white.opacity(0.08)
}

struct StudioButton: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .foregroundStyle(prominent ? Studio.background : Color.white.opacity(0.85))
            .background(prominent ? Studio.accent : Color.white.opacity(configuration.isPressed ? 0.10 : 0.055), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(prominent ? Color.white.opacity(0.15) : Studio.border))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct StudioGroupBox: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            configuration.label.font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
            configuration.content
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        .background(Studio.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Studio.border))
    }
}

struct StudioBadge: View {
    let title: String
    var color: Color = Studio.accent
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(title).font(.system(size: 11, weight: .medium))
        }.foregroundStyle(color).padding(.horizontal, 11).padding(.vertical, 7)
            .background(color.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.16)))
    }
}

struct StudioSection: View {
    let title: String
    var body: some View {
        Text(title.uppercased()).font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.8).foregroundStyle(.white.opacity(0.42))
    }
}

struct StudioChoice: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 24, weight: .light)).foregroundStyle(Studio.accent)
                    .frame(width: 48, height: 48).background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus").foregroundStyle(.secondary)
            }.padding(18).background(Studio.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Studio.border))
        }.buttonStyle(.plain)
    }
}

extension MacroKind {
    var studioSymbol: String {
        switch self {
        case .keys: return "command"
        case .media: return "playpause"
        case .mouse: return "cursorarrow"
        case .micMute: return "mic"
        }
    }
    var studioTitle: String {
        switch self {
        case .keys: return "Zkratka"
        case .media: return "Média"
        case .mouse: return "Myš"
        case .micMute: return "Mikrofon"
        }
    }
}
