import Foundation

/// Loads/saves connections.json in ~/Library/Application Support/SimpleRDP.
final class ConnectionStore {
    private(set) var connections: [Connection] = []

    private let fileURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("SimpleRDP", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("connections.json")
    }()

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? JSONDecoder().decode(ConnectionFile.self, from: data) else {
            connections = []
            return
        }
        connections = file.connections
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let file = ConnectionFile(version: 1, connections: connections)
        guard let data = try? encoder.encode(file) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func add(_ c: Connection) { connections.append(c); save() }

    func update(_ c: Connection) {
        if let i = connections.firstIndex(where: { $0.id == c.id }) { connections[i] = c }
        save()
    }

    func remove(_ c: Connection) {
        connections.removeAll { $0.id == c.id }
        save()
    }
}
