# SimpleRDP — macOS client

An AppKit app that manages the shared `connections.json` and connects via
FreeRDP.

## Status

Slice 1: manage connections (add / edit / delete) and connect. Each connection
opens its own FreeRDP window, so "several at once" still works. Embedding
FreeRDP inside in-app tabs — matching the Windows client — is the next
iteration.

AppKit (not SwiftUI) on purpose: SwiftUI's `@State`/`@Bindable` macros can't be
loaded by a Command Line Tools `swift build`; AppKit builds with just the CLT.

## Requirements

- macOS 13+
- A Swift toolchain (Xcode, or the Command Line Tools)
- FreeRDP at runtime: `brew install freerdp`

## Build & run

```
cd macos
swift build
swift run
```

`swift run` launches an unbundled binary, which is fine for development. For a
distributable **.app**, wrap this target in an Xcode app project (or a bundling
step) — that's on the list.

## Connection store

`~/Library/Application Support/SimpleRDP/connections.json` — the same file and
format the Windows client uses. The Windows-only `passwordEnc` field is
preserved on save but not used here.

## Source layout

| File | Contents |
|------|----------|
| `SimpleRDPApp.swift` | app entry (`@main`) + `AppDelegate` + menu |
| `ContentView.swift` | `MainWindowController` — sidebar list, detail pane, actions |
| `EditSheet.swift` | `EditDialog` (add/edit) + `PasswordDialog` |
| `ConnectionStore.swift` | load/save `connections.json` |
| `Models.swift` | `Connection` / `ScreenSettings` / `ConnectionFile` |
| `RDPLauncher.swift` | finds and launches FreeRDP |

## Roadmap

- [x] Manage connections + connect (own FreeRDP window per session)
- [x] Import from `.rdp` files, search/filter, multi-monitor, connection groups
- [ ] Embed FreeRDP in in-app tabs (match the Windows experience)
- [ ] Ship a signed `.app`
