import AppKit

@main
struct SimpleRDPMain {
    static func main() {
        // Diagnostic: `SimpleRDP --parse <file>` prints the parsed connections and exits.
        if let idx = CommandLine.arguments.firstIndex(of: "--parse"),
           idx + 1 < CommandLine.arguments.count {
            let url = URL(fileURLWithPath: CommandLine.arguments[idx + 1])
            let conns = ConnectionImporter.import(contentsOf: url)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(data: (try? enc.encode(conns)) ?? Data(), encoding: .utf8) ?? "encode failed")
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        let wc = MainWindowController()
        wc.showWindow(nil)
        wc.window?.makeKeyAndOrderFront(nil)
        windowController = wc
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func setupMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit SimpleRDP",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }
}
