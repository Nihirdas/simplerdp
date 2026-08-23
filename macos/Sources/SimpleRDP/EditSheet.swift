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
    private let screenPopup = NSPopUpButton()
    private let widthField = NSTextField()
    private let heightField = NSTextField()
    private let multimon = NSButton(checkboxWithTitle: "Use all monitors", target: nil, action: nil)

    init(connection: Connection, isNew: Bool, groups: [String]) {
        self.connection = connection
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 448),
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

    /// Shows the dialog modally. Returns the edited connection, or nil if cancelled.
    func run() -> Connection? {
        let response = NSApp.runModal(for: panel)
        panel.orderOut(nil)
        guard response == .OK else { return nil }

        connection.name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        connection.host = hostField.stringValue.trimmingCharacters(in: .whitespaces)
        connection.port = Int(portField.stringValue) ?? 3389
        connection.username = userField.stringValue.trimmingCharacters(in: .whitespaces)
        connection.group = groupCombo.stringValue.trimmingCharacters(in: .whitespaces)
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
