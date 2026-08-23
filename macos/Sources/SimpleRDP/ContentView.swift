import AppKit

/// Main window: a sidebar list of connections + a detail pane with Connect.
final class MainWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let store = ConnectionStore()
    private let table = NSTableView()

    private let detailTitle = NSTextField(labelWithString: "")
    private let detailSubtitle = NSTextField(labelWithString: "")
    private let connectButton = NSButton(title: "Connect", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "SimpleRDP"
        window.center()
        window.setFrameAutosaveName("SimpleRDPMain")
        super.init(window: window)

        buildUI()
        store.load()
        table.reloadData()
        updateDetail()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // table
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        col.title = "Connections"
        table.addTableColumn(col)
        table.headerView = nil
        table.rowHeight = 46
        table.usesAutomaticRowHeights = false
        table.style = .inset
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(connectSelected)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let bar = NSStackView(views: [
            button("New", #selector(newConnection)),
            button("Edit", #selector(editSelected)),
            button("Delete", #selector(deleteSelected)),
            button("Connect", #selector(connectSelected)),
        ])
        bar.orientation = .horizontal
        bar.distribution = .fillEqually
        bar.spacing = 6
        bar.translatesAutoresizingMaskIntoConstraints = false

        let left = NSView()
        left.translatesAutoresizingMaskIntoConstraints = false
        left.addSubview(scroll)
        left.addSubview(bar)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: left.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: left.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: left.trailingAnchor),
            bar.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 6),
            bar.leadingAnchor.constraint(equalTo: left.leadingAnchor, constant: 6),
            bar.trailingAnchor.constraint(equalTo: left.trailingAnchor, constant: -6),
            bar.bottomAnchor.constraint(equalTo: left.bottomAnchor, constant: -6),
            bar.heightAnchor.constraint(equalToConstant: 30),
        ])

        // detail pane
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "display", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 42, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor

        detailTitle.font = .systemFont(ofSize: 18, weight: .semibold)
        detailTitle.alignment = .center
        detailSubtitle.textColor = .secondaryLabelColor
        detailSubtitle.alignment = .center

        connectButton.bezelStyle = .rounded
        connectButton.target = self
        connectButton.action = #selector(connectSelected)

        let detail = NSStackView(views: [icon, detailTitle, detailSubtitle, connectButton])
        detail.orientation = .vertical
        detail.alignment = .centerX
        detail.spacing = 10
        detail.translatesAutoresizingMaskIntoConstraints = false

        let right = NSView()
        right.translatesAutoresizingMaskIntoConstraints = false
        right.addSubview(detail)
        NSLayoutConstraint.activate([
            detail.centerXAnchor.constraint(equalTo: right.centerXAnchor),
            detail.centerYAnchor.constraint(equalTo: right.centerYAnchor),
            detail.leadingAnchor.constraint(greaterThanOrEqualTo: right.leadingAnchor, constant: 20),
            detail.trailingAnchor.constraint(lessThanOrEqualTo: right.trailingAnchor, constant: -20),
        ])

        // split
        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false
        split.addArrangedSubview(left)
        split.addArrangedSubview(right)

        let leftWidth = left.widthAnchor.constraint(equalToConstant: 260)
        leftWidth.priority = .defaultLow
        leftWidth.isActive = true
        left.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

        content.addSubview(split)
        NSLayoutConstraint.activate([
            split.topAnchor.constraint(equalTo: content.topAnchor),
            split.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            split.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        return b
    }

    // MARK: - table data

    func numberOfRows(in tableView: NSTableView) -> Int { store.connections.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let c = store.connections[row]
        let name = NSTextField(labelWithString: c.displayName)
        name.font = .boldSystemFont(ofSize: 13)
        let sub = NSTextField(labelWithString: c.subtitle)
        sub.font = .systemFont(ofSize: 11)
        sub.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [name, sub])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        return stack
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateDetail()
    }

    // MARK: - helpers

    private func selectedConnection() -> Connection? {
        let row = table.selectedRow
        guard row >= 0, row < store.connections.count else { return nil }
        return store.connections[row]
    }

    private func reload(select id: String?) {
        table.reloadData()
        if let id, let idx = store.connections.firstIndex(where: { $0.id == id }) {
            table.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        }
        updateDetail()
    }

    private func updateDetail() {
        if let c = selectedConnection() {
            detailTitle.stringValue = c.displayName
            detailSubtitle.stringValue = c.subtitle
            connectButton.isEnabled = true
        } else {
            detailTitle.stringValue = "Select a connection"
            detailSubtitle.stringValue = "…or add one with New"
            connectButton.isEnabled = false
        }
    }

    // MARK: - actions

    @objc private func newConnection() {
        if let c = EditDialog(connection: Connection(), isNew: true).run() {
            store.add(c)
            reload(select: c.id)
        }
    }

    @objc private func editSelected() {
        guard let c = selectedConnection() else { return }
        if let updated = EditDialog(connection: c, isNew: false).run() {
            store.update(updated)
            reload(select: updated.id)
        }
    }

    @objc private func deleteSelected() {
        guard let c = selectedConnection() else { return }
        let alert = NSAlert()
        alert.messageText = "Delete \"\(c.displayName)\"?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.remove(c)
            reload(select: nil)
        }
    }

    @objc private func connectSelected() {
        guard let c = selectedConnection() else { return }
        guard let password = PasswordDialog.run(for: c) else { return }
        if let err = RDPLauncher.launch(c, password: password) {
            let alert = NSAlert()
            alert.messageText = "Connect"
            alert.informativeText = err
            alert.runModal()
        }
    }
}
