namespace SimpleRDP.Models;

/// <summary>Root of connections.json — shared with the macOS client.</summary>
public class ConnectionFile
{
    public int Version { get; set; } = 1;
    public List<Connection> Connections { get; set; } = new();
}

public class Connection
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Name { get; set; } = string.Empty;
    public string Host { get; set; } = string.Empty;
    public int Port { get; set; } = 3389;
    public string Username { get; set; } = string.Empty;

    /// <summary>Optional folder/group name for the sidebar. Empty = ungrouped.</summary>
    public string Group { get; set; } = string.Empty;

    /// <summary>Optional accent color as #RRGGBB. Empty = none.</summary>
    public string Color { get; set; } = string.Empty;

    public ScreenSettings Screen { get; set; } = new();
    public bool FullScreen { get; set; }

    /// <summary>Span the session across all monitors (RDP multimon).</summary>
    public bool UseAllMonitors { get; set; }

    /// <summary>
    /// Base64 DPAPI blob encrypted for the current Windows user. Optional.
    /// The macOS client preserves this field on round-trip but cannot read it.
    /// </summary>
    public string? PasswordEnc { get; set; }

    public override string ToString()
        => string.IsNullOrWhiteSpace(Name) ? $"{Host}:{Port}" : Name;

    public Connection Clone() => new()
    {
        Id = Id,
        Name = Name,
        Host = Host,
        Port = Port,
        Username = Username,
        Group = Group,
        Color = Color,
        FullScreen = FullScreen,
        UseAllMonitors = UseAllMonitors,
        PasswordEnc = PasswordEnc,
        Screen = new ScreenSettings { Mode = Screen.Mode, Width = Screen.Width, Height = Screen.Height }
    };
}

public class ScreenSettings
{
    /// <summary>"fit" (scale to the tab) or "fixed" (use Width/Height).</summary>
    public string Mode { get; set; } = "fit";
    public int Width { get; set; } = 1280;
    public int Height { get; set; } = 800;
}
