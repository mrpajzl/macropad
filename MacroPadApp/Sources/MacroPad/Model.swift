import Foundation

// MARK: - Datový model

enum MacroKind: String, Codable, CaseIterable, Identifiable {
    case keys, media, mouse, micMute
    var id: String { rawValue }
    var title: String {
        switch self {
        case .keys: return "Zkratka"
        case .media: return "Media"
        case .mouse: return "Myš"
        case .micMute: return "🎙 Mikrofon"
        }
    }
}

struct Chord: Codable, Hashable {
    var mods: UInt8
    var code: UInt8
    var label: String {
        var parts: [String] = []
        if mods & 0x01 != 0 || mods & 0x10 != 0 { parts.append("⌃") }
        if mods & 0x04 != 0 || mods & 0x40 != 0 { parts.append("⌥") }
        if mods & 0x02 != 0 || mods & 0x20 != 0 { parts.append("⇧") }
        if mods & 0x08 != 0 || mods & 0x80 != 0 { parts.append("⌘") }
        parts.append(HID.name(for: code))
        return parts.joined()
    }
}

enum MouseAction: String, Codable, CaseIterable, Identifiable {
    case left, right, middle, wheelUp, wheelDown
    var id: String { rawValue }
    var title: String {
        switch self {
        case .left: return "Levé tlačítko"
        case .right: return "Pravé tlačítko"
        case .middle: return "Prostřední tlačítko"
        case .wheelUp: return "Kolečko ↑"
        case .wheelDown: return "Kolečko ↓"
        }
    }
    /// (buttons, dx, dy, wheel)
    var bytes: (UInt8, UInt8, UInt8, UInt8) {
        switch self {
        case .left: return (1, 0, 0, 0)
        case .right: return (2, 0, 0, 0)
        case .middle: return (4, 0, 0, 0)
        case .wheelUp: return (0, 0, 0, 1)
        case .wheelDown: return (0, 0, 0, 0xff)
        }
    }
}

struct MediaKey: Identifiable, Hashable {
    let code: UInt16; let title: String
    var id: UInt16 { code }
    static let all: [MediaKey] = [
        .init(code: 0xe9, title: "Hlasitost +"), .init(code: 0xea, title: "Hlasitost −"), .init(code: 0xe2, title: "Ztlumit zvuk"),
        .init(code: 0xcd, title: "Play / Pause"), .init(code: 0xb7, title: "Stop"), .init(code: 0xb5, title: "Další skladba"),
        .init(code: 0xb6, title: "Předchozí skladba"), .init(code: 0x6f, title: "Jas +"), .init(code: 0x70, title: "Jas −"),
        .init(code: 0x192, title: "Kalkulačka"), .init(code: 0x19e, title: "Zámek obrazovky"), .init(code: 0x223, title: "Web – domů"),
        .init(code: 0x224, title: "Web – zpět"), .init(code: 0x225, title: "Web – vpřed"), .init(code: 0x182, title: "Oblíbené"),
    ]
}

struct MacroDef: Codable, Hashable {
    var kind: MacroKind = .keys
    var chords: [Chord] = []
    var media: UInt16 = 0xe9
    var mouse: MouseAction = .left
}

struct Slot: Identifiable, Hashable {
    let id: UInt8       // protokolové ID klávesy
    let title: String
    let symbol: String
    static let keys: [Slot] = [
        .init(id: 1, title: "Klávesa 1", symbol: "1.square"),
        .init(id: 2, title: "Klávesa 2", symbol: "2.square"),
        .init(id: 3, title: "Klávesa 3", symbol: "3.square"),
    ]
    static let knob: [Slot] = [
        .init(id: 13, title: "Knob ← doleva", symbol: "arrow.counterclockwise"),
        .init(id: 14, title: "Knob – stisk", symbol: "circle.circle"),
        .init(id: 15, title: "Knob → doprava", symbol: "arrow.clockwise"),
    ]
    static let all = keys + knob
}

struct PadConfig: Codable {
    enum CodingKeys: String, CodingKey { case slots, layer, micHotkey, knobOnRight, keysReversed }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        slots = try c.decodeIfPresent([UInt8: MacroDef].self, forKey: .slots) ?? [:]
        layer = try c.decodeIfPresent(UInt8.self, forKey: .layer) ?? 0
        micHotkey = try c.decodeIfPresent(Chord.self, forKey: .micHotkey) ?? Chord(mods: 0, code: 0x6d)
        knobOnRight = try c.decodeIfPresent(Bool.self, forKey: .knobOnRight) ?? true
        keysReversed = try c.decodeIfPresent(Bool.self, forKey: .keysReversed) ?? false
    }
    var slots: [UInt8: MacroDef] = [:]
    var layer: UInt8 = 0
    /// Klávesa, kterou pad pošle Macu a appka na ni přepne mikrofon (default F18).
    var micHotkey: Chord = Chord(mods: 0, code: 0x6d)
    /// Fyzické rozložení (jen pro zobrazení)
    var knobOnRight: Bool = true
    var keysReversed: Bool = false

    /// Klávesy v pořadí zleva doprava tak, jak jsou fyzicky na padu
    var physicalKeys: [Slot] { keysReversed ? Slot.keys.reversed() : Slot.keys }

    subscript(slot: UInt8) -> MacroDef {
        get { slots[slot] ?? MacroDef() }
        set { slots[slot] = newValue }
    }

    static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MacroPad", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()
    static let xiaoFileURL = fileURL.deletingLastPathComponent().appendingPathComponent("config-xiao.json")
    static func load(from url: URL = fileURL) -> PadConfig {
        guard let d = try? Data(contentsOf: url), let c = try? JSONDecoder().decode(PadConfig.self, from: d) else { return PadConfig() }
        return c
    }
    func save(to url: URL = PadConfig.fileURL) {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? enc.encode(self).write(to: url)
    }
}

// MARK: - Protokol (kompatibilní s ch57x-keyboard-tool, model 1189:8890)

enum PadProtocol {
    static func packets(config: PadConfig, slot: UInt8) -> [[UInt8]] {
        let m = config[slot]
        let layer = config.layer
        var out: [[UInt8]] = [[0x03, 0xfe, layer + 1, 0x01, 0x01]]
        let kl: UInt8 = (layer + 1) << 4
        switch m.kind {
        case .keys, .micMute:
            let chords = m.kind == .micMute ? [config.micHotkey] : Array(m.chords.prefix(5))
            let presses = [Chord(mods: 0, code: 0)] + chords   // firmware chce prázdný stisk na začátku
            for (i, c) in presses.enumerated() {
                out.append([0x03, slot, kl | 0x01, UInt8(chords.count), UInt8(i), c.mods, c.code, 0, 0])
            }
        case .media:
            out.append([0x03, slot, kl | 0x02, UInt8(m.media & 0xff), UInt8(m.media >> 8), 0, 0, 0, 0])
        case .mouse:
            let b = m.mouse.bytes
            out.append([0x03, slot, kl | 0x03, b.0, b.1, b.2, b.3, 0, 0])
        }
        out.append([0x03, 0xaa, 0xaa])
        return out
    }
    static func ledPackets(mode: UInt8) -> [[UInt8]] {
        [[0x03, 0xa1, 0x01], [0x03, 0xb0, 0x18, mode], [0x03, 0xaa, 0xa1]]
    }
    static func hex(_ p: [UInt8]) -> String { p.map { String(format: "%02x", $0) }.joined(separator: " ") }
}

// MARK: - HID tabulky

enum HID {
    /// macOS virtual keycode → (HID usage, název)
    static let keyMap: [UInt16: (UInt8, String)] = {
        var m: [UInt16: (UInt8, String)] = [:]
        let letters: [(UInt16, String)] = [(0,"A"),(11,"B"),(8,"C"),(2,"D"),(14,"E"),(3,"F"),(5,"G"),(4,"H"),(34,"I"),(38,"J"),(40,"K"),(37,"L"),(46,"M"),(45,"N"),(31,"O"),(35,"P"),(12,"Q"),(15,"R"),(1,"S"),(17,"T"),(32,"U"),(9,"V"),(13,"W"),(7,"X"),(16,"Y"),(6,"Z")]
        for (k, n) in letters { m[k] = (UInt8(4 + Int(n.unicodeScalars.first!.value) - 65), n) }
        let digits: [(UInt16, String, UInt8)] = [(18,"1",30),(19,"2",31),(20,"3",32),(21,"4",33),(23,"5",34),(22,"6",35),(26,"7",36),(28,"8",37),(25,"9",38),(29,"0",39)]
        for (k, n, u) in digits { m[k] = (u, n) }
        let others: [(UInt16, UInt8, String)] = [
            (36,40,"↩"),(53,41,"Esc"),(51,42,"⌫"),(48,43,"⇥"),(49,44,"Space"),(27,45,"-"),(24,46,"="),(33,47,"["),(30,48,"]"),(42,49,"\\"),
            (41,51,";"),(39,52,"'"),(50,53,"`"),(43,54,","),(47,55,"."),(44,56,"/"),(57,57,"⇪"),
            (122,58,"F1"),(120,59,"F2"),(99,60,"F3"),(118,61,"F4"),(96,62,"F5"),(97,63,"F6"),(98,64,"F7"),(100,65,"F8"),(101,66,"F9"),(109,67,"F10"),(103,68,"F11"),(111,69,"F12"),
            (105,104,"F13"),(107,105,"F14"),(113,106,"F15"),(106,107,"F16"),(64,108,"F17"),(79,109,"F18"),(80,110,"F19"),(90,111,"F20"),
            (114,73,"Ins"),(115,74,"Home"),(116,75,"PgUp"),(117,76,"⌦"),(119,77,"End"),(121,78,"PgDn"),(124,79,"→"),(123,80,"←"),(125,81,"↓"),(126,82,"↑"),
            (71,83,"NumLock"),(75,84,"KP/"),(67,85,"KP*"),(78,86,"KP-"),(69,87,"KP+"),(76,88,"KP↩"),(83,89,"KP1"),(84,90,"KP2"),(85,91,"KP3"),(86,92,"KP4"),(87,93,"KP5"),(88,94,"KP6"),(89,95,"KP7"),(91,96,"KP8"),(92,97,"KP9"),(82,98,"KP0"),(65,99,"KP."),(10,100,"§"),
        ]
        for (k, u, n) in others { m[k] = (u, n) }
        return m
    }()
    static let names: [UInt8: String] = {
        var d: [UInt8: String] = [:]
        for (_, v) in keyMap { d[v.0] = v.1 }
        return d
    }()
    static func name(for usage: UInt8) -> String { names[usage] ?? String(format: "0x%02x", usage) }
}
