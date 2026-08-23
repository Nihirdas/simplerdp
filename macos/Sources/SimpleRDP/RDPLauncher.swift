import Foundation

/// Launches an RDP session by shelling out to FreeRDP.
///
/// Slice 1 opens each session as its own FreeRDP window (so "several at once"
/// still works). Embedding FreeRDP inside in-app tabs — matching the Windows
/// client — is the next iteration.
enum RDPLauncher {
    private static let candidates = [
        "/opt/homebrew/bin/sdl-freerdp3", "/opt/homebrew/bin/sdl-freerdp",
        "/opt/homebrew/bin/xfreerdp3",   "/opt/homebrew/bin/xfreerdp",
        "/usr/local/bin/sdl-freerdp3",   "/usr/local/bin/sdl-freerdp",
        "/usr/local/bin/xfreerdp3",      "/usr/local/bin/xfreerdp",
    ]

    static func freerdpPath() -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Returns nil on success, or a user-facing error message.
    static func launch(_ c: Connection, password: String?) -> String? {
        guard let bin = freerdpPath() else {
            return "FreeRDP was not found.\n\nInstall it with Homebrew:\n    brew install freerdp\n\nThen try connecting again."
        }

        var args = ["/v:\(c.host):\(c.port)", "/cert:ignore", "+clipboard", "/dynamic-resolution"]
        if !c.username.isEmpty { args.append("/u:\(c.username)") }
        if let p = password, !p.isEmpty { args.append("/p:\(p)") }
        if c.screen.mode == "fixed" {
            args.append("/size:\(c.screen.width)x\(c.screen.height)")
        } else {
            args.append("/size:1280x800")
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = args
        do {
            try proc.run()
            return nil
        } catch {
            return "Could not launch FreeRDP:\n\(error.localizedDescription)"
        }
    }
}
