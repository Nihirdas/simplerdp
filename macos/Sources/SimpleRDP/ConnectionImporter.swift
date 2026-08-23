import Foundation

/// Dispatches an import file to the right parser by extension.
enum ConnectionImporter {
    static func `import`(contentsOf url: URL) -> [Connection] {
        switch url.pathExtension.lowercased() {
        case "rdp": return RdpImport.parse(contentsOf: url).map { [$0] } ?? []
        case "rdg": return RdgImport.parse(contentsOf: url)
        case "xml": return MRemoteNgImport.parse(contentsOf: url)
        default: return []
        }
    }
}
