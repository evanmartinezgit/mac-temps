import Foundation
import IOKit

struct Sensor: Identifiable {
    var id: String
    var type: UInt32
    var size: UInt32
    var value: Double?
    var peak: Double?
    var label: SensorLabel { SensorCatalog.label(for: id) }
    var name: String { label.name }
    var group: String { label.group }
    var mappingStatus: String { label.status }
}

// AppleSMC user-client ABI, 80-byte request/response. Only read commands are used.
final class SensorReader {
    private var connection: io_connect_t = 0
    private(set) var sensors: [Sensor] = []
    private(set) var error: String?
    private func code(_ s: String) -> UInt32 { s.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }
    private func uint(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        (0..<4).reduce(0) { $0 | (UInt32(bytes[offset + $1]) << (8 * $1)) }
    }
    private func call(key: UInt32 = 0, command: UInt8, size: UInt32 = 0, index: UInt32 = 0) -> [UInt8]? {
        var input = [UInt8](repeating: 0, count: 80)
        func put(_ value: UInt32, _ offset: Int) {
            for i in 0..<4 { input[offset+i] = UInt8(truncatingIfNeeded: value >> (i*8)) }
        }
        put(key, 0); put(size, 28); input[42] = command; put(index, 44)
        var output = [UInt8](repeating: 0, count: 80)
        var count = 80
        let result = input.withUnsafeBytes { inp in
            output.withUnsafeMutableBytes { out in
                IOConnectCallStructMethod(connection, 2, inp.baseAddress, 80, out.baseAddress, &count)
            }
        }
        return result == KERN_SUCCESS && count == 80 && output[40] == 0 ? output : nil
    }
    init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { error = "AppleSMC is unavailable on this Mac."; return }
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
        guard result == KERN_SUCCESS else { error = "Could not open temperature sensors (\(result))."; return }
        guard let info = call(key: code("#KEY"), command: 9),
              let data = call(key: code("#KEY"), command: 5, size: uint(info, 28)) else {
            error = "Could not enumerate temperature sensors."; return
        }
        let count = data[48..<52].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard count > 0 && count < 20000 else { error = "Unexpected sensor count."; return }
        for i in 0..<count {
            guard let entry = call(command: 8, index: i) else { continue }
            let key = uint(entry, 0)
            let name = String(bytes: (0..<4).reversed().map { UInt8(truncatingIfNeeded: key >> ($0*8)) }, encoding: .ascii) ?? ""
            guard name.hasPrefix("T"), let metadata = call(key: key, command: 9) else { continue }
            let type = uint(metadata, 32), size = uint(metadata, 28)
            guard (type == code("flt ") && size == 4) || (type == code("sp78") && size == 2) else { continue }
            sensors.append(Sensor(id: name, type: type, size: size))
        }
        sensors.sort { $0.id < $1.id }
        if sensors.isEmpty { error = "No supported temperature channels were found." }
    }
    func read() -> [Sensor] {
        for i in sensors.indices {
            var value: Double?
            if let data = call(key: code(sensors[i].id), command: 5, size: sensors[i].size) {
                let raw: Double
                if sensors[i].type == code("flt ") { raw = Double(Float(bitPattern: uint(data, 48))) }
                else { raw = Double(Int16(bitPattern: UInt16(data[48]) << 8 | UInt16(data[49]))) / 256 }
                // Zero/negative values are usually disconnected or inactive channels on this machine.
                if raw.isFinite && raw > 0 && raw < 150 { value = raw }
            }
            sensors[i].value = value
            if let value { sensors[i].peak = max(value, sensors[i].peak ?? value) }
        }
        return sensors
    }
    deinit { if connection != 0 { IOServiceClose(connection) } }
}
