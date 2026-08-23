# SimpleRDP

A small, local multi-tab RDP client for Windows and macOS.

Save your servers by IP, open several at once in tabs, connect. No account, no
workspace, no cloud sync, no subscription. Your connection list is a plain JSON
file on your own machine.

## Status

Early but usable. The **Windows** client (embedded multi-tab RDP) is furthest
along. The **macOS** client manages connections and launches FreeRDP; embedding
sessions in tabs there is the next step.

## Layout

```
windows/   C#/.NET (WinForms) client — one Microsoft RDP ActiveX control per tab
macos/     Swift/AppKit client — manages connections, launches FreeRDP
shared/    connection file format shared by both clients
docs/      landing page (GitHub Pages)
```

## Connection store

Both clients read/write the same file:

- Windows: `%APPDATA%\SimpleRDP\connections.json`
- macOS: `~/Library/Application Support/SimpleRDP/connections.json`

See [`shared/connections.example.json`](shared/connections.example.json) for the
format.

## Build (Windows)

Requires Windows 10/11, the .NET 8 SDK, and Visual Studio 2022 (or the Build
Tools).

```
cd windows
dotnet build -c Release
```

Or open `windows/SimpleRDP.sln` in Visual Studio and run.

The project references the Microsoft RDP ActiveX control (`mstscax.dll`) via a
COM reference; Visual Studio resolves it and generates the interop assemblies
automatically. If a command-line build can't generate the interop, add the
reference once in Visual Studio: **Project → Add → COM Reference → "Microsoft
RDP Client Control"** (latest version), then build again.

## Roadmap

- [x] Saved connections (add / edit / delete), local JSON store
- [x] Connect to a server in a tab; multiple sessions at once
- [x] Remember password, encrypted with Windows DPAPI
- [x] Reconnect + per-tab status dots and a close button (Windows)
- [x] macOS client — manage connections + connect via FreeRDP (own window per session)
- [ ] Embed FreeRDP in macOS tabs (match the Windows in-app experience)
- [ ] Import from `.rdp` files

## License

MIT — see [LICENSE](LICENSE).
