import Foundation

/// Imports a Remote Desktop Connection Manager (.rdg) file. Folders become groups.
enum RdgImport {
    static func parse(contentsOf url: URL) -> [Connection] {
        guard let data = try? Data(contentsOf: url),
              let doc = try? XMLDocument(data: data, options: []),
              let root = doc.rootElement() else { return [] }
        var out: [Connection] = []
        walk(root, group: "", into: &out)
        return out
    }

    private static func walk(_ el: XMLElement, group: String, into out: inout [Connection]) {
        for case let e as XMLElement in el.children ?? [] {
            switch e.name {
            case "group":
                walk(e, group: propertyName(e) ?? group, into: &out)
            case "server":
                if let c = server(e, group: group) { out.append(c) }
            default:
                walk(e, group: group, into: &out)   // <file> and other containers
            }
        }
    }

    private static func propertyName(_ group: XMLElement) -> String? {
        for case let e as XMLElement in group.children ?? [] where e.name == "properties" {
            return childText(e, "name")
        }
        return nil
    }

    private static func server(_ e: XMLElement, group: String) -> Connection? {
        var props: XMLElement?, creds: XMLElement?, settings: XMLElement?
        for case let c as XMLElement in e.children ?? [] {
            switch c.name {
            case "properties": props = c
            case "logonCredentials": creds = c
            case "connectionSettings": settings = c
            default: break
            }
        }
        guard let host = props.flatMap({ childText($0, "name") }), !host.isEmpty else { return nil }

        var conn = Connection()
        conn.host = host
        conn.name = props.flatMap { childText($0, "displayName") } ?? host
        conn.group = group
        if let user = creds.flatMap({ childText($0, "userName") }), !user.isEmpty {
            let domain = creds.flatMap { childText($0, "domain") } ?? ""
            conn.username = domain.isEmpty ? user : "\(domain)\\\(user)"
        }
        if let portStr = settings.flatMap({ childText($0, "port") }), let p = Int(portStr) {
            conn.port = p
        }
        return conn
    }

    private static func childText(_ parent: XMLElement, _ name: String) -> String? {
        for case let e as XMLElement in parent.children ?? [] where e.name == name {
            return e.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
