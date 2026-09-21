import SwiftUI
import AppKit

final class Temperatures: ObservableObject {
    @Published var sensors: [Sensor] = []
    @Published var error: String?
    @Published var updated: Date?
    private let queue = DispatchQueue(label: "temperature-reader", qos: .utility)
    private var reader: SensorReader?
    private var timer: Timer?
    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.reader == nil { self.reader = SensorReader() }
            let values = self.reader!.read(), error = self.reader!.error
            DispatchQueue.main.async {
                self.sensors = values; self.error = error; self.updated = Date()
            }
        }
    }
    func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Mac Temperatures.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let csv = "Sensor,Name,Group,Mapping,Current Celsius,Session Peak Celsius\n" + sensors.map {
            "\($0.id),\($0.name),\($0.group),\($0.mappingStatus),\($0.value.map { String(format: "%.2f", $0) } ?? ""),\($0.peak.map { String(format: "%.2f", $0) } ?? "")"
        }.joined(separator: "\n")
        do { try csv.write(to: url, atomically: true, encoding: .utf8) }
        catch { let alert = NSAlert(); alert.messageText = "Export failed"; alert.informativeText = error.localizedDescription; alert.runModal() }
    }
}

struct ContentView: View {
    @StateObject private var model = Temperatures()
    @State private var query = ""
    @State private var group = "All sensors"
    @State private var fahrenheit = false
    @State private var hottestFirst = false
    private let groups = ["All sensors", "CPU", "GPU", "Battery", "Memory", "Storage", "Connectivity", "Airflow", "Power", "Other sensors"]
    private var filtered: [Sensor] {
        let result = model.sensors.filter {
            (group == "All sensors" || $0.group == group) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.mappingStatus.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query) || $0.group.localizedCaseInsensitiveContains(query))
        }
        return hottestFirst ? result.sorted { ($0.value ?? -.infinity) > ($1.value ?? -.infinity) } : result
    }
    private func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f°%@", fahrenheit ? value * 1.8 + 32 : value, fahrenheit ? "F" : "C")
    }
    private func summary(_ title: String, symbol: String, color: Color) -> some View {
        let values = model.sensors.filter { $0.group == title && $0.mappingStatus == "Community mapped" }.compactMap(\.value)
        return VStack(alignment: .leading, spacing: 10) {
            Label(title.uppercased(), systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(color)
            Text(format(values.max())).font(.system(size: 32, weight: .medium, design: .rounded)).monospacedDigit()
            Text("Highest of \(values.count) mapped channels").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Mac Temps").font(.largeTitle.bold())
                    Text("Live hardware temperature channels").foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("°F", isOn: $fahrenheit).toggleStyle(.switch).fixedSize()
                Button { model.export() } label: { Image(systemName: "square.and.arrow.up") }.help("Export all readings as CSV")
            }
            HStack(spacing: 12) {
                summary("CPU", symbol: "cpu", color: .orange)
                summary("GPU", symbol: "square.3.layers.3d", color: .purple)
                summary("Battery", symbol: "battery.100percent", color: .green)
            }
            HStack {
                Picker("Group", selection: $group) { ForEach(groups, id: \.self) { Text($0) } }.labelsHidden().frame(width: 180)
                TextField("Search name, ID, or mapping status", text: $query).textFieldStyle(.roundedBorder)
                Toggle("Hottest first", isOn: $hottestFirst).toggleStyle(.checkbox)
            }
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
            Table(filtered) {
                TableColumn("Sensor") { sensor in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sensor.name).lineLimit(1)
                        Text(sensor.id).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    }.help(sensor.label.detail)
                }.width(min: 240, ideal: 300)
                TableColumn("Mapping") { sensor in
                    Text(sensor.mappingStatus).foregroundStyle(sensor.mappingStatus == "Community mapped" ? Color.secondary : Color.orange).help(sensor.label.detail)
                }.width(min: 110, ideal: 130)
                TableColumn("Group", value: \.group)
                TableColumn("Temperature") { sensor in Text(format(sensor.value)).monospacedDigit().fontWeight(.semibold) }
                TableColumn("Session peak") { sensor in Text(format(sensor.peak)).monospacedDigit().foregroundStyle(.secondary) }
            }.clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Circle().fill(model.error == nil ? Color.green : Color.orange).frame(width: 7, height: 7)
                    Text("\(model.sensors.filter { $0.value != nil }.count) reporting / \(model.sensors.count) discovered · refreshes every 2 seconds")
                    Spacer()
                    if let date = model.updated { Text(date, style: .time).monospacedDigit() }
                }
                Text("Names are community mappings for this M1 Max. Tentative and disputed channels are excluded from summaries. Hover a name for evidence. Unknown IDs remain visible. — means no valid reading.")
                    .fixedSize(horizontal: false, vertical: true)
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(minWidth: 1000, minHeight: 580)
    }
}

@main struct MacTempsApp: App {
    var body: some Scene {
        WindowGroup("Mac Temps") { ContentView() }.defaultSize(width: 1100, height: 760)
    }
}
