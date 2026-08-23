using System.Xml.Linq;
using SimpleRDP.Models;

namespace SimpleRDP.Services;

/// <summary>Imports a Remote Desktop Connection Manager (.rdg) file. Folders become groups.</summary>
public static class RdgImporter
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
        foreach (var e in el.Elements())
        {
            switch (e.Name.LocalName)
            {
                case "group":
                    Walk(e, PropName(e) ?? group, list);
                    break;
                case "server":
                    var c = Server(e, group);
                    if (c != null) list.Add(c);
                    break;
                default:
                    Walk(e, group, list); // <file> and other containers
                    break;
            }
        }
    }

    private static string? PropName(XElement group)
    {
        var props = group.Elements().FirstOrDefault(x => x.Name.LocalName == "properties");
        return props != null ? ChildText(props, "name") : null;
    }

    private static Connection? Server(XElement e, string group)
    {
        var props = e.Elements().FirstOrDefault(x => x.Name.LocalName == "properties");
        var creds = e.Elements().FirstOrDefault(x => x.Name.LocalName == "logonCredentials");
        var settings = e.Elements().FirstOrDefault(x => x.Name.LocalName == "connectionSettings");

        var host = props != null ? ChildText(props, "name") : null;
        if (string.IsNullOrWhiteSpace(host)) return null;

        var c = new Connection { Host = host!, Group = group };
        c.Name = (props != null ? ChildText(props, "displayName") : null) ?? host!;

        if (creds != null)
        {
            var user = ChildText(creds, "userName");
            var domain = ChildText(creds, "domain");
            if (!string.IsNullOrWhiteSpace(user))
                c.Username = string.IsNullOrWhiteSpace(domain) ? user! : $"{domain}\\{user}";
        }

        if (settings != null && int.TryParse(ChildText(settings, "port"), out var port)) c.Port = port;
        return c;
    }

    private static string? ChildText(XElement parent, string localName)
        => parent.Elements().FirstOrDefault(x => x.Name.LocalName == localName)?.Value.Trim();
}
