using System.Xml.Linq;
using SimpleRDP.Models;

namespace SimpleRDP.Services;

/// <summary>
/// Imports an mRemoteNG confCons.xml. Containers become groups; only RDP nodes
/// are imported. Encrypted passwords are ignored.
/// </summary>
public static class MRemoteNgImporter
{
    public static List<Connection> Parse(string path)
    {
        var doc = XDocument.Load(path);
        var list = new List<Connection>();
        if (doc.Root != null) Walk(doc.Root, "", list);
        return list;
    }

    private static void Walk(XElement el, string group, List<Connection> list)
    {
        foreach (var e in el.Elements().Where(x => x.Name.LocalName == "Node"))
        {
            var type = (string?)e.Attribute("Type") ?? "";
            if (type == "Container")
            {
                Walk(e, (string?)e.Attribute("Name") ?? group, list);
            }
            else if (type == "Connection")
            {
                var proto = ((string?)e.Attribute("Protocol") ?? "RDP").ToUpperInvariant();
                if (proto != "RDP") continue;

                var host = (string?)e.Attribute("Hostname");
                if (string.IsNullOrWhiteSpace(host)) continue;

                var c = new Connection { Host = host!, Group = group };
                c.Name = (string?)e.Attribute("Name") ?? host!;

                var user = (string?)e.Attribute("Username") ?? "";
                var domain = (string?)e.Attribute("Domain") ?? "";
                if (!string.IsNullOrWhiteSpace(user))
                    c.Username = string.IsNullOrWhiteSpace(domain) ? user : $"{domain}\\{user}";

                if (int.TryParse((string?)e.Attribute("Port"), out var port)) c.Port = port;
                list.Add(c);
            }
        }
    }
}
