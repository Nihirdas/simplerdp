import AppKit

/// Modal add/edit dialog for a single connection.
final class EditDialog: NSObject {
    private let panel: NSPanel
    private var connection: Connection

    private let nameField = NSTextField()
    private let hostField = NSTextField()
    private let portField = NSTextField()
    private let userField = NSTextField()
    private let groupCombo = NSComboBox()
    private let colorEnable = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let colorWell = NSColorWell()
    private let screenPopup = NSPopUpButton()
    private let widthField = NSTextField()
    private let heightField = NSTextField()
    private let multimon = NSButton(checkboxWithTitle: "Use all monitors", target: nil, action: nil)

    init(connection: Connection, isNew: Bool, groups: [String]) {
        self.connection = connection
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 484),
            styleMask: [.titled], backing: .buffered, defer: false)
        super.init()

        panel.title = isNew ? "New connection" : "Edit connection"

        nameField.stringValue = connection.name
        hostField.stringValue = connection.host
        portField.stringValue = String(connection.port)
        userField.stringValue = connection.username
        groupCombo.isEditable = true
        groupCombo.completes = true
        groupCombo.addItems(withObjectValues: groups)
        groupCombo.stringValue = connection.group
        screenPopup.addItems(withTitles: ["Fit to window", "Fixed size"])
        screenPopup.selectItem(at: connection.screen.mode == "fixed" ? 1 : 0)
        widthField.stringValue = String(connection.screen.width)
        heightField.stringValue = String(connection.screen.height)
        multimon.state = connection.useAllMonitors ? .on : .off

        if !connection.color.isEmpty, let c = NSColor(hex: connection.color) {
            colorEnable.state = .on
            colorWell.color = c
        } else {
            colorEnable.state = .off
            colorWell.color = .systemBlue
        }
        let colorRow = NSStackView(views: [colorEnable, colorWell])
        colorRow.orientation = .horizontal
        colorRow.spacing = 8
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.widthAnchor.constraint(equalToConstant: 60).isActive = true

        setWidth(nameField, 250)
        setWidth(hostField, 250)
        setWidth(userField, 250)
        setWidth(groupCombo, 250)
        setWidth(portField, 90)
        setWidth(widthField, 90)
        setWidth(heightField, 90)

        let grid = NSGridView(views: [
            [label("Name"), nameField],
            [label("Host / IP"), hostField],
            [label("Port"), portField],
            [label("Username"), userField],
            [label("Group"), groupCombo],
            [label("Color"), colorRow],
            [label("Screen"), screenPopup],
            [label("Width"), widthField],
            [label("Height"), heightField],
            [label("Monitors"), multimon],
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: isNew ? "Add" : "Save", target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        let buttons = NSStackView(views: [cancelButton, saveButton])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let content = panel.contentView!
        content.addSubview(grid)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: grid.bottomAnchor, constant: 18),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])
    }

    func run() -> Connection? {
        let response = NSApp.runModal(for: panel)
        panel.orderOut(nil)
        guard response == .OK else { return nil }

        connection.name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        connection.host = hostField.stringValue.trimmingCharacters(in: .whitespaces)
        connection.port = Int(portField.stringValue) ?? 3389
        connection.username = userField.stringValue.trimmingCharacters(in: .whitespaces)
        connection.group = groupCombo.stringValue.trimmingCharacters(in: .whitespaces)
        connection.color = colorEnable.state == .on ? colorWell.color.toHexRGB() : ""
        connection.screen.mode = screenPopup.indexOfSelectedItem == 1 ? "fixed" : "fit"
        connection.screen.width = Int(widthField.stringValue) ?? 1280
        connection.screen.height = Int(heightField.stringValue) ?? 800
        connection.useAllMonitors = (multimon.state == .on)
        return connection
    }

    @objc private func save() {
        guard !hostField.stringValue.trimmingCharacters(in: .whitespaces).isEmpty else {
            NSSound.beep()
            return
        }
        NSApp.stopModal(withCode: .OK)
    }

    @objc private func cancel() {
        NSApp.stopModal(withCode: .cancel)
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func setWidth(_ field: NSView, _ width: CGFloat) {
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
    }
}

/// Password prompt shown at connect time (not persisted on macOS).
enum PasswordDialog {
    static func run(for c: Connection) -> String? {
        let alert = NSAlert()
        alert.messageText = "Connect to \(c.displayName)"
        alert.informativeText = c.subtitle
        alert.addButton(withTitle: "Connect")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Password (optional)"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xff) / 255,
                  green: CGFloat((v >> 8) & 0xff) / 255,
                  blue: CGFloat(v & 0xff) / 255,
                  alpha: 1)
    }

    func toHexRGB() -> String {
        guard let c = usingColorSpace(.sRGB) else { return "" }
        return String(format: "#%02X%02X%02X",
                      Int(round(c.redComponent * 255)),
                      Int(round(c.greenComponent * 255)),
                      Int(round(c.blueComponent * 255)))
    }
}
