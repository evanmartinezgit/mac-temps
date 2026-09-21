import Foundation
@main struct Probe {
 static func main() {
    let reader = SensorReader()
    let sensors = reader.read()
    if let error = reader.error { print(error); exit(1) }
    for s in sensors { print("\(s.id) \(s.group) \(s.value.map { String(format: "%.1f°C", $0) } ?? "unavailable")") }
    print("Total: \(sensors.count), active: \(sensors.filter { $0.value != nil }.count)")
 }
}
