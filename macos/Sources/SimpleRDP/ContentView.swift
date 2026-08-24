import AppKit
import UniformTypeIdentifiers

/// Main window: a searchable, grouped sidebar list + a detail pane with Connect.
final class MainWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private enum Row {
        case header(String)
        case connection(Connection)
    }

    private let store = ConnectionStore()
    private var displayRows: [Row] = []

    private let searchField = NSSearchField()
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
        reload(select: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        col.title = "Connections"
        table.addTableColumn(col)
        table.headerView = nil
        table.rowHeight = 46
        table.usesAutomaticRowHeights = false
        table.floatsGroupRows = false
        table.style = .inset
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(connectSelected)
        table.menu = buildRowMenu()

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search"
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.sendsWholeSearchString = false
        searchField.sendsSearchStringImmediately = true

        let bar = NSStackView(views: [
            button("New", #selector(newConnection)),
            button("Import", #selector(importConnections)),
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
        left.addSubview(searchField)
        left.addSubview(scroll)
        left.addSubview(bar)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: left.topAnchor, constant: 6),
            searchField.leadingAnchor.constraint(equalTo: left.leadingAnchor, constant: 6),
            searchField.trailingAnchor.constraint(equalTo: left.trailingAnchor, constant: -6),

            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 6),
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

    private func buildRowMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Connect", action: #selector(menuConnect), keyEquivalent: "")
        menu.addItem(withTitle: "Edit", action: #selector(menuEdit), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Move Up", action: #selector(menuMoveUp), keyEquivalent: "")
        menu.addItem(withTitle: "Move Down", action: #selector(menuMoveDown), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Delete", action: #selector(menuDelete), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        return menu
    }

    // MARK: - table data

    func numberOfRows(in tableView: NSTableView) -> Int { displayRows.count }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        if case .header = displayRows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .header = displayRows[row] { return false }
        return true
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if case .header = displayRows[row] { return 24 }
        return 46
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch displayRows[row] {
        case .header(let title):
            let label = NSTextField(labelWithString: title.uppercased())
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = .secondaryLabelColor
            let wrap = NSStackView(views: [label])
            wrap.orientation = .horizontal
            wrap.edgeInsets = NSEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
            return wrap

        case .connection(let c):
            let name = NSTextField(labelWithString: c.displayName)
            name.font = .boldSystemFont(ofSize: 13)
            let sub = NSTextField(labelWithString: c.subtitle)
            sub.font = .systemFont(ofSize: 11)
            sub.textColor = .secondaryLabelColor

            let textStack = NSStackView(views: [name, sub])
            textStack.orientation = .vertical
            textStack.alignment = .leading
            textStack.spacing = 2

            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)

            if !c.color.isEmpty, let col = NSColor(hex: c.color) {
                let dot = NSView()
                dot.wantsLayer = true
                dot.layer?.backgroundColor = col.cgColor
                dot.layer?.cornerRadius = 3
                dot.translatesAutoresizingMaskIntoConstraints = false
                dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
                dot.heightAnchor.constraint(equalToConstant: 24).isActive = true
                row.addArrangedSubview(dot)
            }
            row.addArrangedSubview(textStack)
            return row
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateDetail()
    }

    // MARK: - helpers

    private func selectedConnection() -> Connection? {
        connection(at: table.selectedRow)
    }

    private func clickedConnection() -> Connection? {
        connection(at: table.clickedRow)
    }

    private func connection(at row: Int) -> Connection? {
        guard row >= 0, row < displayRows.count else { return nil }
        if case .connection(let c) = displayRows[row] { return c }
        return nil
    }

    private func existingGroups() -> [String] {
        Array(Set(store.connections.map { $0.group }.filter { !$0.isEmpty }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func applyFilter() {
        let q = searchField.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        let matches: (Connection) -> Bool = { c in
            q.isEmpty
                || c.displayName.lowercased().contains(q)
                || c.host.lowercased().contains(q)
                || c.username.lowercased().contains(q)
                || c.group.lowercased().contains(q)
        }
        let filtered = store.connections.filter(matches)

        if !q.isEmpty {
            displayRows = filtered.map { .connection($0) }
            return
        }

        let named = Set(filtered.map { $0.group }.filter { !$0.isEmpty })
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        if named.isEmpty {
            displayRows = filtered.map { .connection($0) }
            return
        }

        var out: [Row] = []
        for g in named {
            out.append(.header(g))
            out.append(contentsOf: filtered.filter { $0.group == g }.map { .connection($0) })
        }
        let ungrouped = filtered.filter { $0.group.isEmpty }
        if !ungrouped.isEmpty {
            out.append(.header("Ungrouped"))
            out.append(contentsOf: ungrouped.map { .connection($0) })
        }
        displayRows = out
    }

    private func reload(select id: String?) {
        applyFilter()
        table.reloadData()
        if let id {
            for (i, row) in displayRows.enumerated() {
                if case .connection(let c) = row, c.id == id {
                    table.selectRowIndexes(IndexSet(integer: i), byExtendingSelection: false)
                    break
                }
            }
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

    // MARK: - operations

    private func connect(_ c: Connection) {
        guard let password = PasswordDialog.run(for: c) else { return }
        if let err = RDPLauncher.launch(c, password: password) {
            let alert = NSAlert()
            alert.messageText = "Connect"
            alert.informativeText = err
            alert.runModal()
        }
    }

    private func edit(_ c: Connection) {
        if let updated = EditDialog(connection: c, isNew: false, groups: existingGroups()).run() {
            store.update(updated)
            reload(select: updated.id)
        }
    }

    private func delete(_ c: Connection) {
        let alert = NSAlert()
        alert.messageText = "Delete \"\(c.displayName)\"?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.remove(c)
            reload(select: nil)
        }
    }

    // MARK: - actions (toolbar buttons act on the selected row)

    @objc private func searchChanged() { reload(select: selectedConnection()?.id) }

    @objc private func newConnection() {
        if let c = EditDialog(connection: Connection(), isNew: true, groups: existingGroups()).run() {
            store.add(c)
            reload(select: c.id)
        }
    }

    @objc private func importConnections() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = ["rdp", "rdg", "xml"].compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK else { return }

        var last: String?
        for url in panel.urls {
            for c in ConnectionImporter.import(contentsOf: url) {
                store.add(c)
                last = c.id
            }
        }
        reload(select: last)
    }

    @objc private func connectSelected() { if let c = selectedConnection() { connect(c) } }
    @objc private func editSelected() { if let c = selectedConnection() { edit(c) } }
    @objc private func deleteSelected() { if let c = selectedConnection() { delete(c) } }

    // MARK: - actions (context menu acts on the right-clicked row)

    @objc private func menuConnect() { if let c = clickedConnection() { connect(c) } }
    @objc private func menuEdit() { if let c = clickedConnection() { edit(c) } }
    @objc private func menuDelete() { if let c = clickedConnection() { delete(c) } }
    @objc private func menuMoveUp() { if let c = clickedConnection() { store.moveUp(c); reload(select: c.id) } }
    @objc private func menuMoveDown() { if let c = clickedConnection() { store.moveDown(c); reload(select: c.id) } }
}
