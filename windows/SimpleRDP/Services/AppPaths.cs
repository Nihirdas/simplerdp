namespace SimpleRDP.Services;

public static class AppPaths
{
    /// <summary>%APPDATA%\SimpleRDP, created on first access.</summary>
    public static string DataDir
    {
        get
        {
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "SimpleRDP");
            Directory.CreateDirectory(dir);
            return dir;
        }
    }

    public static string ConnectionsFile => Path.Combine(DataDir, "connections.json");
}
