using System.Drawing;
using System.Windows.Forms;
using SimpleRDP.Models;

namespace SimpleRDP.UI;

public readonly record struct PasswordResult(string Password, bool Remember);

/// <summary>Asks for a password at connect time, with an optional "remember" (DPAPI).</summary>
public class PasswordPrompt : Form
{
    private readonly TextBox _pw = new() { UseSystemPasswordChar = true, Dock = DockStyle.Fill };
    private readonly CheckBox _remember = new()
    {
        Text = "Remember password on this PC",
        Dock = DockStyle.Top,
        Height = 26,
        Padding = new Padding(12, 2, 12, 2)
    };

    private PasswordPrompt(Connection c, bool rememberDefault)
    {
        Text = "Connect";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterParent;
        MaximizeBox = false;
        MinimizeBox = false;
        ClientSize = new Size(360, 190);

        var target = $"{c.Host}:{c.Port}"
                     + (string.IsNullOrWhiteSpace(c.Username) ? "" : $"  ·  {c.Username}");
        var info = new Label
        {
            Dock = DockStyle.Top,
            Height = 52,
            Padding = new Padding(12, 12, 12, 0),
            Text = $"{c}\r\n{target}"
        };

        var pwPanel = new Panel { Dock = DockStyle.Top, Height = 46, Padding = new Padding(12, 8, 12, 6) };
        _pw.PlaceholderText = "Password (blank = prompt on the remote)";
        pwPanel.Controls.Add(_pw);

        _remember.Checked = rememberDefault;

        var ok = new Button { Text = "Connect", DialogResult = DialogResult.OK, AutoSize = true };
        var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, AutoSize = true };
        var buttons = new FlowLayoutPanel
        {
            Dock = DockStyle.Bottom,
            FlowDirection = FlowDirection.RightToLeft,
            Height = 44,
            Padding = new Padding(8)
        };
        buttons.Controls.Add(ok);
        buttons.Controls.Add(cancel);

        // Add Top controls in reverse visual order (last added docks highest):
        // want info, then password, then the remember checkbox.
        Controls.Add(_remember);
        Controls.Add(pwPanel);
        Controls.Add(info);
        Controls.Add(buttons);
        AcceptButton = ok;
        CancelButton = cancel;
    }

    /// <summary>Returns the entered password and remember flag, or null if cancelled.</summary>
    public static PasswordResult? Ask(IWin32Window owner, Connection c, bool rememberDefault)
    {
        using var dlg = new PasswordPrompt(c, rememberDefault);
        return dlg.ShowDialog(owner) == DialogResult.OK
            ? new PasswordResult(dlg._pw.Text, dlg._remember.Checked)
            : null;
    }
}
