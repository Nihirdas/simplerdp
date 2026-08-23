using System.Drawing;
using System.Windows.Forms;
using SimpleRDP.Models;

namespace SimpleRDP.UI;

/// <summary>Add / edit a single connection.</summary>
public class ConnectionDialog : Form
{
    private readonly TextBox _name = new();
    private readonly TextBox _host = new();
    private readonly NumericUpDown _port = new() { Minimum = 1, Maximum = 65535, Value = 3389 };
    private readonly TextBox _user = new();
    private readonly ComboBox _mode = new() { DropDownStyle = ComboBoxStyle.DropDownList };
    private readonly NumericUpDown _width = new() { Minimum = 640, Maximum = 7680, Value = 1280, Increment = 10 };
    private readonly NumericUpDown _height = new() { Minimum = 480, Maximum = 4320, Value = 800, Increment = 10 };
    private readonly CheckBox _multimon = new() { Text = "Use all monitors", Dock = DockStyle.Fill };

    private readonly Connection _result;

    private ConnectionDialog(Connection? existing)
    {
        _result = existing?.Clone() ?? new Connection();

        Text = existing == null ? "New connection" : "Edit connection";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterParent;
        MaximizeBox = false;
        MinimizeBox = false;
        ClientSize = new Size(400, 350);

        _mode.Items.AddRange(new object[] { "Fit to window", "Fixed size" });

        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            Padding = new Padding(12)
        };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));

        AddRow(layout, "Name", _name);
        AddRow(layout, "Host / IP", _host);
        AddRow(layout, "Port", _port);
        AddRow(layout, "Username", _user);
        AddRow(layout, "Screen", _mode);
        AddRow(layout, "Width", _width);
        AddRow(layout, "Height", _height);
        AddRow(layout, "Monitors", _multimon);

        // populate
        _name.Text = _result.Name;
        _host.Text = _result.Host;
        _port.Value = Clamp(_result.Port, 1, 65535);
        _user.Text = _result.Username;
        _mode.SelectedIndex = _result.Screen.Mode == "fixed" ? 1 : 0;
        _width.Value = Clamp(_result.Screen.Width, 640, 7680);
        _height.Value = Clamp(_result.Screen.Height, 480, 4320);
        _multimon.Checked = _result.UseAllMonitors;
        _mode.SelectedIndexChanged += (_, _) => UpdateSizeEnabled();
        UpdateSizeEnabled();

        var ok = new Button { Text = "Save", DialogResult = DialogResult.OK, AutoSize = true };
        var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, AutoSize = true };
        ok.Click += (_, _) => Commit();

        var buttons = new FlowLayoutPanel
        {
            Dock = DockStyle.Bottom,
            FlowDirection = FlowDirection.RightToLeft,
            Height = 44,
            Padding = new Padding(8)
        };
        buttons.Controls.Add(ok);
        buttons.Controls.Add(cancel);

        Controls.Add(layout);   // fill (added first = back)
        Controls.Add(buttons);  // bottom bar (added after = front)
        AcceptButton = ok;
        CancelButton = cancel;
    }

    private static decimal Clamp(int v, int lo, int hi) => Math.Min(Math.Max(v, lo), hi);

    private void UpdateSizeEnabled()
    {
        var fixedMode = _mode.SelectedIndex == 1;
        _width.Enabled = fixedMode;
        _height.Enabled = fixedMode;
    }

    private static void AddRow(TableLayoutPanel t, string label, Control field)
    {
        field.Dock = DockStyle.Fill;
        var l = new Label { Text = label, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft };
        var row = t.RowCount++;
        t.RowStyles.Add(new RowStyle(SizeType.Absolute, 32));
        t.Controls.Add(l, 0, row);
        t.Controls.Add(field, 1, row);
    }

    private void Commit()
    {
        _result.Name = _name.Text.Trim();
        _result.Host = _host.Text.Trim();
        _result.Port = (int)_port.Value;
        _result.Username = _user.Text.Trim();
        _result.Screen.Mode = _mode.SelectedIndex == 1 ? "fixed" : "fit";
        _result.Screen.Width = (int)_width.Value;
        _result.Screen.Height = (int)_height.Value;
        _result.UseAllMonitors = _multimon.Checked;
    }

    /// <summary>Returns the edited connection, or null if cancelled.</summary>
    public static Connection? Edit(IWin32Window owner, Connection? existing)
    {
        using var dlg = new ConnectionDialog(existing);
        dlg.FormClosing += (_, e) =>
        {
            if (dlg.DialogResult != DialogResult.OK) return;
            if (!string.IsNullOrWhiteSpace(dlg._host.Text)) return;
            MessageBox.Show(dlg, "Host / IP is required.", "SimpleRDP",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
            e.Cancel = true;
        };
        return dlg.ShowDialog(owner) == DialogResult.OK ? dlg._result : null;
    }
}
