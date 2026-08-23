import Foundation

/// Imports an mRemoteNG confCons.xml. Containers become groups; only RDP nodes
/// are imported. Encrypted passwords are ignored.
enum MRemoteNgImport {
    static func parse(contentsOf url: URL) -> [Connection] {
        guard let data = try? Data(contentsOf: url),
              let doc = try? XMLDocument(data: data, options: []),
              let root = doc.rootElement() else { return [] }
        var out: [Connection] = []
        walk(root, group: "", into: &out)
        return out
    }

    private static func walk(_ el: XMLElement, group: String, into out: inout [Connection]) {
        for case let e as XMLElement in el.children ?? [] where e.name == "Node" {
            switch attr(e, "Type") ?? "" {
            case "Container":
                walk(e, group: attr(e, "Name") ?? group, into: &out)
            case "Connection":
                let proto = (attr(e, "Protocol") ?? "RDP").uppercased()
                guard proto == "RDP", let host = attr(e, "Hostname"), !host.isEmpty else { continue }
                var conn = Connection()
                conn.host = host
                conn.name = attr(e, "Name") ?? host
                conn.group = group
                let user = attr(e, "Username") ?? ""
                let domain = attr(e, "Domain") ?? ""
                if !user.isEmpty { conn.username = domain.isEmpty ? user : "\(domain)\\\(user)" }
                if let portStr = attr(e, "Port"), let p = Int(portStr) { conn.port = p }
                out.append(conn)
            default:
                break
            }
        }
    }

    private static func attr(_ e: XMLElement, _ name: String) -> String? {
        e.attribute(forName: name)?.stringValue
    }
}
