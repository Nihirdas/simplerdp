using System.Text.Json;
using SimpleRDP.Models;

namespace SimpleRDP.Services;

/// <summary>Loads and saves connections.json (camelCase, shared with macOS).</summary>
public class ConnectionStore
{
    private static readonly JsonSerializerOptions Json = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true
    };

    private ConnectionFile _data = new();

    public IReadOnlyList<Connection> Connections => _data.Connections;

    public void Load()
    {
        var path = AppPaths.ConnectionsFile;
        if (!File.Exists(path))
        {
            _data = new ConnectionFile();
            return;
        }

        try
        {
            _data = JsonSerializer.Deserialize<ConnectionFile>(File.ReadAllText(path), Json)
                    ?? new ConnectionFile();
        }
        catch
        {
            // Corrupt or unreadable file — start clean rather than crash.
            _data = new ConnectionFile();
        }
    }

    public void Save()
        => File.WriteAllText(AppPaths.ConnectionsFile, JsonSerializer.Serialize(_data, Json));

    public void Add(Connection c)
    {
        _data.Connections.Add(c);
        Save();
    }

    public void Update(Connection c)
    {
        var i = _data.Connections.FindIndex(x => x.Id == c.Id);
        if (i >= 0) _data.Connections[i] = c;
        else _data.Connections.Add(c);
        Save();
    }

    public void Remove(Connection c)
    {
        _data.Connections.RemoveAll(x => x.Id == c.Id);
        Save();
    }

    public bool MoveUp(Connection c) => Move(c, -1);
    public bool MoveDown(Connection c) => Move(c, +1);

    /// <summary>Swaps a connection with its nearest same-group neighbour in the given direction.</summary>
    private bool Move(Connection c, int dir)
    {
        var list = _data.Connections;
        var i = list.IndexOf(c);
        if (i < 0) return false;
        for (var j = i + dir; j >= 0 && j < list.Count; j += dir)
        {
            if (string.Equals(list[j].Group, c.Group, StringComparison.OrdinalIgnoreCase))
            {
                (list[i], list[j]) = (list[j], list[i]);
                Save();
                return true;
            }
        }
        return false;
    }
}
