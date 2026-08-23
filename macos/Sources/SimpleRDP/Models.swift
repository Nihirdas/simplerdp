import Foundation

/// Mirrors the Windows client's model so both read/write the same connections.json.
struct ScreenSettings: Codable, Hashable {
    var mode: String = "fit"   // "fit" or "fixed"
    var width: Int = 1280
    var height: Int = 800
}

struct Connection: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    var name: String = ""
    var host: String = ""
    var port: Int = 3389
    var username: String = ""
    var group: String = ""
    var screen: ScreenSettings = .init()
    var fullScreen: Bool = false
    var useAllMonitors: Bool = false

    /// Windows DPAPI blob. Preserved on round-trip but not usable on macOS.
    var passwordEnc: String? = nil

    var displayName: String { name.isEmpty ? "\(host):\(port)" : name }
    var subtitle: String {
        username.isEmpty ? "\(host):\(port)" : "\(host):\(port) · \(username)"
    }
}

struct ConnectionFile: Codable {
    var version: Int = 1
    var connections: [Connection] = []
}
