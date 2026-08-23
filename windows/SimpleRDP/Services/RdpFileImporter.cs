using SimpleRDP.Models;

namespace SimpleRDP.Services;

/// <summary>
/// Parses a standard Windows .rdp file (key:type:value lines) into a Connection.
/// Only the fields SimpleRDP uses are read; everything else is ignored.
/// </summary>
public static class RdpFileImporter
{
    public static Connection Parse(string path)
        => Parse(File.ReadAllLines(path), Path.GetFileNameWithoutExtension(path));

    public static Connection Parse(IEnumerable<string> lines, string fallbackName)
    {
        var c = new Connection { Name = fallbackName };
        int? width = null, height = null;

        foreach (var raw in lines)
        {
            var line = raw.Trim();
            if (line.Length == 0) continue;

            // Format is  key:type:value  — value itself may contain ':'.
            var first = line.IndexOf(':');
            if (first < 0) continue;
            var second = line.IndexOf(':', first + 1);
            if (second < 0) continue;

            var key = line[..first].Trim().ToLowerInvariant();
            var value = line[(second + 1)..].Trim();

            switch (key)
            {
                case "full address":
                    var (host, port) = SplitHostPort(value);
                    c.Host = host;
                    if (port.HasValue) c.Port = port.Value;
                    break;
                case "username":
                    c.Username = value;
                    break;
                case "desktopwidth":
                    if (int.TryParse(value, out var w)) width = w;
                    break;
                case "desktopheight":
                    if (int.TryParse(value, out var h)) height = h;
                    break;
                case "use multimon":
                    c.UseAllMonitors = value == "1";
                    break;
            }
        }

        if (width is > 0 && height is > 0)
        {
            c.Screen.Mode = "fixed";
            c.Screen.Width = width.Value;
            c.Screen.Height = height.Value;
        }

        return c;
    }

    private static (string host, int? port) SplitHostPort(string s)
    {
        var idx = s.LastIndexOf(':');
        if (idx > 0 && int.TryParse(s[(idx + 1)..], out var port)) return (s[..idx], port);
        return (s, null);
    }
}
