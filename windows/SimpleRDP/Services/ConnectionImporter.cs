using SimpleRDP.Models;

namespace SimpleRDP.Services;

/// <summary>Dispatches an import file to the right parser by extension.</summary>
public static class ConnectionImporter
{
    public static List<Connection> Import(string path)
        => Path.GetExtension(path).ToLowerInvariant() switch
        {
            ".rdp" => new List<Connection> { RdpFileImporter.Parse(path) },
            ".rdg" => RdgImporter.Parse(path),
            ".xml" => MRemoteNgImporter.Parse(path),
            _ => new List<Connection>()
        };
}
