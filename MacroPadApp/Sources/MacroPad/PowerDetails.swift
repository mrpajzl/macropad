import SwiftUI
import Charts

struct PowerDetails: View {
    @ObservedObject var pad: LearningPad
    var body: some View {
        TimelineView(.periodic(from: .now, by: 10)) { timeline in
            let fresh = pad.power?.isFresh(at: timeline.date) == true && pad.ready
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    StudioSection(title: "Energie a zařízení")
                    Spacer()
                    Image(systemName: "wave.3.right").foregroundStyle(Studio.accent)
                }
                HStack(alignment: .center, spacing: 18) {
                    Image(systemName: fresh && pad.power?.mode == .charging ? "battery.100.bolt" : "battery.100")
                        .font(.system(size: 38, weight: .light)).foregroundStyle(fresh ? Studio.accent : .gray)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(pad.power?.percent.map { "\($0) %" } ?? "—")
                            .font(.system(size: 38, weight: .medium, design: .rounded)).monospacedDigit()
                        Text(!pad.ready ? "MacroPad je odpojený" : !fresh ? "Čekám na aktuální měření" : pad.power?.mode.rawValue ?? "Stav neznámý")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                if !pad.powerHistory.samples.isEmpty {
                    Chart(Array(pad.powerHistory.samples.enumerated()), id: \.offset) { item in
                        if let percent = item.element.percent {
                            PointMark(x: .value("Čas", item.element.date), y: .value("Baterie", percent))
                                .foregroundStyle(Studio.accent).symbolSize(8)
                            LineMark(x: .value("Čas", item.element.date), y: .value("Baterie", percent))
                                .foregroundStyle(Studio.accent).interpolationMethod(.linear)
                        }
                    }
                    .chartXScale(domain: min(pad.powerHistory.samples.first?.date ?? timeline.date, timeline.date.addingTimeInterval(-900))...timeline.date)
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine(); AxisValueLabel(format: .dateTime.hour().minute())
                    } }
                    .chartYScale(domain: 0...100).chartYAxis { AxisMarks(values: [0, 50, 100]) }
                    .frame(height: 110)
                    .accessibilityLabel("Vývoj stavu baterie za aktuální režim napájení, nejvýše poslední hodina")
                }
                VStack(spacing: 13) {
                    row("Napětí baterie", fresh ? pad.power?.millivolts.map { String(format: "%.2f V", Double($0) / 1000) } ?? "Nedostupné" : "—")
                    row(pad.power?.mode == .charging ? "Rychlost nabíjení" : "Rychlost vybíjení",
                        fresh ? pad.powerHistory.rate.map { String(format: "≈ %.1f p. b./h", abs($0)) } ?? (pad.power?.mode == .usb ? "Nabíjení neprobíhá" : pad.power?.mode == .unknown ? "Nedostupné" : "Sbírám měření…") : "—")
                    if let profile = pad.power?.profile { row("Aktivní Bluetooth profil", fresh ? "\(profile + 1)" : "—") }
                    if let uptime = pad.power?.uptime { row("Od zapnutí", fresh ? duration(uptime) : "—") }
                    row("Bluetooth signál", fresh ? pad.signal.map { "\($0) dBm" } ?? "—" : "—")
                }
                Rectangle().fill(Studio.border).frame(height: 1)
                Text(pad.supportsPower
                     ? "Procenta jsou odhad z napětí. Trend se ukáže po alespoň 15 minutách a změně o 2 procentní body. Při změně napájení začíná nové měření. XIAO neměří proud v mA."
                     : "Tento firmware poskytuje jen základní stav baterie. Pro nabíjení a napětí nahrajte aktuální firmware v nastavení zařízení.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Kontrolka CHG přímo na XIAO svítí při nabíjení. Zhasnutí samo o sobě nepotvrzuje plnou baterii.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let date = pad.power?.date {
                    Text("Přijato: \(date.formatted(date: .omitted, time: .standard)) · napětí měřeno po 60 s")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                }
            }.padding(26).frame(width: 390).background(Studio.surface).preferredColorScheme(.dark)
        }
        .onAppear { pad.refreshPower() }
    }
    private func row(_ title: String, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).monospacedDigit() }.font(.system(size: 12))
    }
    private func duration(_ seconds: UInt32) -> String {
        seconds < 3600 ? "\(seconds / 60) min" : "\(seconds / 3600) h \((seconds % 3600) / 60) min"
    }
}
