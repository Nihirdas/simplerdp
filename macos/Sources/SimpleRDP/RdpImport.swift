import Foundation

/// Parses a standard Windows .rdp file (key:type:value lines) into a Connection.
enum RdpImport {
    static func parse(contentsOf url: URL) -> Connection? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return parse(text: text, fallbackName: url.deletingPathExtension().lastPathComponent)
    }

    static func parse(text: String, fallbackName: String) -> Connection {
        var c = Connection()
        c.name = fallbackName
        var width: Int?
        var height: Int?

        for rawLine in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            // key:type:value  — value may itself contain ':'
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 3 else { continue }
            let key = parts[0].lowercased()
            let value = parts[2...].joined(separator: ":").trimmingCharacters(in: .whitespaces)

            switch key {
            case "full address":
                let (host, port) = splitHostPort(value)
                c.host = host
                if let port { c.port = port }
            case "username":
                c.username = value
            case "desktopwidth":
                width = Int(value)
            case "desktopheight":
                height = Int(value)
            case "use multimon":
                c.useAllMonitors = (value == "1")
            default:
                break
            }
        }

        if let w = width, let h = height, w > 0, h > 0 {
            c.screen.mode = "fixed"
            c.screen.width = w
            c.screen.height = h
        }
        return c
    }

    private static func splitHostPort(_ s: String) -> (String, Int?) {
        if let idx = s.lastIndex(of: ":") {
            let portStr = String(s[s.index(after: idx)...])
            if let p = Int(portStr) { return (String(s[..<idx]), p) }
        }
        return (s, nil)
    }
}
