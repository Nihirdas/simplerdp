using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
using SimpleRDP.Models;
using SimpleRDP.Services;

namespace SimpleRDP.UI;

public class MainForm : Form
{
    private readonly ConnectionStore _store = new();
    private readonly TextBox _search = new()
    {
        Dock = DockStyle.Fill,
        PlaceholderText = "Search…",
        Margin = new Padding(6, 4, 6, 4)
    };
    private readonly ListBox _list = new()
    {
        Dock = DockStyle.Fill,
        IntegralHeight = false,
        DrawMode = DrawMode.OwnerDrawFixed,
        ItemHeight = 44
    };
    private readonly TabControl _tabs = new()
    {
        Dock = DockStyle.Fill,
        DrawMode = TabDrawMode.OwnerDrawFixed,
        Padding = new Point(24, 6)
    };
    private SplitContainer _split = null!;
    private ToolStripMenuItem _miClearPw = null!;

    public MainForm()
    {
        Text = "SimpleRDP";
        MinimumSize = new Size(820, 520);
        Size = new Size(1200, 780);
        StartPosition = FormStartPosition.CenterScreen;

        BuildUi();
        _store.Load();
        RefreshList();
    }

    private void BuildUi()
    {
        _split = new SplitContainer { Dock = DockStyle.Fill, FixedPanel = FixedPanel.Panel1 };

        // ---- sidebar ----
        var side = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 4 };
        side.RowStyles.Add(new RowStyle(SizeType.Absolute, 30));  // header
        side.RowStyles.Add(new RowStyle(SizeType.Absolute, 34));  // search
        side.RowStyles.Add(new RowStyle(SizeType.Percent, 100));  // list
        side.RowStyles.Add(new RowStyle(SizeType.Absolute, 44));  // buttons

        var header = new Label
        {
            Text = "Connections",
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleLeft,
            Padding = new Padding(8, 0, 0, 0),
            Font = new Font(Font, FontStyle.Bold)
        };

        _search.TextChanged += (_, _) => RefreshList();

        _list.DoubleClick += (_, _) => ConnectSelected();
        _list.KeyDown += (_, e) => { if (e.KeyCode == Keys.Enter) ConnectSelected(); };
        _list.DrawItem += List_DrawItem;
        _list.MouseDown += List_MouseDown;
        _list.ContextMenuStrip = BuildListMenu();

        var bar = new FlowLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(4) };
        bar.Controls.Add(MakeButton("New", (_, _) => NewConnection()));
        bar.Controls.Add(MakeButton("Import", (_, _) => ImportRdp()));
        bar.Controls.Add(MakeButton("Edit", (_, _) => EditSelected()));
        bar.Controls.Add(MakeButton("Delete", (_, _) => DeleteSelected()));
        bar.Controls.Add(MakeButton("Connect", (_, _) => ConnectSelected()));

        side.Controls.Add(header, 0, 0);
        side.Controls.Add(_search, 0, 1);
        side.Controls.Add(_list, 0, 2);
        side.Controls.Add(bar, 0, 3);
        _split.Panel1.Controls.Add(side);

        // ---- sessions ----
        _tabs.DrawItem += Tabs_DrawItem;
        _tabs.MouseDown += Tabs_MouseDown;
        _tabs.MouseUp += Tabs_MouseUp;
        _split.Panel2.Controls.Add(_tabs);

        Controls.Add(_split);
    }

    private ContextMenuStrip BuildListMenu()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add("Connect", null, (_, _) => ConnectSelected());
        menu.Items.Add("Edit", null, (_, _) => EditSelected());
        menu.Items.Add("Delete", null, (_, _) => DeleteSelected());
        menu.Items.Add(new ToolStripSeparator());
        _miClearPw = new ToolStripMenuItem("Clear saved password", null, (_, _) => ClearSavedPassword());
        menu.Items.Add(_miClearPw);
        menu.Opening += (_, _) =>
        {
            var c = _list.SelectedItem as Connection;
            _miClearPw.Enabled = c != null && !string.IsNullOrEmpty(c.PasswordEnc);
        };
        return menu;
    }

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        try { _split.SplitterDistance = 260; } catch { /* ignore sizing race */ }
    }

    private static Button MakeButton(string text, EventHandler onClick)
    {
        var b = new Button { Text = text, AutoSize = true, Margin = new Padding(3) };
        b.Click += onClick;
        return b;
    }

    private void RefreshList()
    {
        var selectedId = (_list.SelectedItem as Connection)?.Id;
        var q = _search.Text.Trim();

        _list.BeginUpdate();
        _list.Items.Clear();
        foreach (var c in _store.Connections)
            if (Matches(c, q)) _list.Items.Add(c);
        _list.EndUpdate();

        if (selectedId == null) return;
        for (var i = 0; i < _list.Items.Count; i++)
        {
            if (_list.Items[i] is Connection c && c.Id == selectedId)
            {
                _list.SelectedIndex = i;
                break;
            }
        }
    }

    private static bool Matches(Connection c, string q)
    {
        if (q.Length == 0) return true;
        return c.Name.Contains(q, StringComparison.OrdinalIgnoreCase)
            || c.Host.Contains(q, StringComparison.OrdinalIgnoreCase)
            || c.Username.Contains(q, StringComparison.OrdinalIgnoreCase);
    }

    // ---- sidebar drawing ----

    private void List_DrawItem(object? sender, DrawItemEventArgs e)
    {
        if (e.Index < 0 || _list.Items[e.Index] is not Connection c) return;

        e.DrawBackground();
        var selected = (e.State & DrawItemState.Selected) != 0;
        var g = e.Graphics;
        var r = e.Bounds;

        var nameColor = selected ? SystemColors.HighlightText : SystemColors.ControlText;
        var subColor = selected ? SystemColors.HighlightText : Color.Gray;

        using var nameFont = new Font(Font, FontStyle.Bold);
        TextRenderer.DrawText(g, c.ToString(), nameFont,
            new Rectangle(r.Left + 8, r.Top + 5, r.Width - 40, 18), nameColor,
            TextFormatFlags.Left | TextFormatFlags.EndEllipsis);

        var sub = $"{c.Host}:{c.Port}"
                  + (string.IsNullOrWhiteSpace(c.Username) ? "" : $"  ·  {c.Username}");
        TextRenderer.DrawText(g, sub, Font,
            new Rectangle(r.Left + 8, r.Top + 23, r.Width - 40, 16), subColor,
            TextFormatFlags.Left | TextFormatFlags.EndEllipsis);

        if (!string.IsNullOrEmpty(c.PasswordEnc))
            DrawPadlock(g, new Point(r.Right - 22, r.Top + r.Height / 2 - 6), subColor);

        e.DrawFocusRectangle();
    }

    private static void DrawPadlock(Graphics g, Point at, Color color)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        using var pen = new Pen(color, 1.4f);
        using var brush = new SolidBrush(color);
        g.DrawArc(pen, at.X + 3, at.Y, 8, 9, 180, 180); // shackle
        g.FillRectangle(brush, at.X + 1, at.Y + 4, 12, 8); // body
    }

    private void List_MouseDown(object? sender, MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Right) return;
        var idx = _list.IndexFromPoint(e.Location);
        if (idx >= 0) _list.SelectedIndex = idx;
    }

    // ---- tab drawing ----

    private void Tabs_DrawItem(object? sender, DrawItemEventArgs e)
    {
        var g = e.Graphics;
        var page = _tabs.TabPages[e.Index];
        var rect = _tabs.GetTabRect(e.Index);
        var selected = e.Index == _tabs.SelectedIndex;

        using (var bg = new SolidBrush(selected ? SystemColors.Window : SystemColors.Control))
            g.FillRectangle(bg, rect);

        g.SmoothingMode = SmoothingMode.AntiAlias;

        var state = (page.Tag as RdpSessionControl)?.State ?? RdpSessionState.Connecting;
        var dot = state switch
        {
            RdpSessionState.Connected => Color.FromArgb(52, 199, 89),
            RdpSessionState.Connecting => Color.FromArgb(255, 179, 64),
            _ => Color.FromArgb(255, 90, 80)
        };
        const int d = 8;
        var dx = rect.Left + 8;
        var dy = rect.Top + (rect.Height - d) / 2;
        using (var db = new SolidBrush(dot)) g.FillEllipse(db, dx, dy, d, d);

        var xr = CloseGlyphRect(rect);
        using (var pen = new Pen(Color.Gray, 1.6f))
        {
            var xi = Rectangle.Inflate(xr, -3, -3);
            g.DrawLine(pen, xi.Left, xi.Top, xi.Right, xi.Bottom);
            g.DrawLine(pen, xi.Right, xi.Top, xi.Left, xi.Bottom);
        }

        var textRect = Rectangle.FromLTRB(dx + d + 6, rect.Top, xr.Left - 4, rect.Bottom);
        TextRenderer.DrawText(g, page.Text, Font, textRect,
            selected ? SystemColors.ControlText : SystemColors.ControlDarkDark,
            TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
    }

    private static Rectangle CloseGlyphRect(Rectangle tab)
    {
        const int s = 15;
        return new Rectangle(tab.Right - s - 7, tab.Top + (tab.Height - s) / 2, s, s);
    }

    private void Tabs_MouseDown(object? sender, MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left) return;
        for (var i = 0; i < _tabs.TabPages.Count; i++)
        {
            var rect = _tabs.GetTabRect(i);
            if (!rect.Contains(e.Location)) continue;
            if (Rectangle.Inflate(CloseGlyphRect(rect), 3, 3).Contains(e.Location))
                RemoveTab(_tabs.TabPages[i]);
            break;
        }
    }

    private void Tabs_MouseUp(object? sender, MouseEventArgs e)
    {
        for (var i = 0; i < _tabs.TabPages.Count; i++)
        {
            if (!_tabs.GetTabRect(i).Contains(e.Location)) continue;
            if (e.Button == MouseButtons.Middle) RemoveTab(_tabs.TabPages[i]);
            else if (e.Button == MouseButtons.Right) _tabs.SelectedIndex = i;
            break;
        }
    }

    // ---- actions ----

    private void NewConnection()
    {
        var c = ConnectionDialog.Edit(this, null);
        if (c == null) return;
        _store.Add(c);
        RefreshList();
    }

    private void ImportRdp()
    {
        using var dlg = new OpenFileDialog
        {
            Title = "Import .rdp files",
            Filter = "Remote Desktop files (*.rdp)|*.rdp|All files (*.*)|*.*",
            Multiselect = true
        };
        if (dlg.ShowDialog(this) != DialogResult.OK) return;

        var imported = 0;
        foreach (var path in dlg.FileNames)
        {
            try
            {
                _store.Add(RdpFileImporter.Parse(path));
                imported++;
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, $"Couldn't import {Path.GetFileName(path)}:\n{ex.Message}",
                    "SimpleRDP", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
        if (imported > 0) RefreshList();
    }

    private void EditSelected()
    {
        if (_list.SelectedItem is not Connection sel) return;
        var c = ConnectionDialog.Edit(this, sel);
        if (c == null) return;
        _store.Update(c);
        RefreshList();
    }

    private void DeleteSelected()
    {
        if (_list.SelectedItem is not Connection sel) return;
        if (MessageBox.Show(this, $"Delete \"{sel}\"?", "SimpleRDP",
                MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
        _store.Remove(sel);
        RefreshList();
    }

    private void ClearSavedPassword()
    {
        if (_list.SelectedItem is not Connection sel || string.IsNullOrEmpty(sel.PasswordEnc)) return;
        sel.PasswordEnc = null;
        _store.Update(sel);
        RefreshList();
    }

    private void ConnectSelected()
    {
        if (_list.SelectedItem is not Connection sel) return;

        string? password = null;
        var hasSaved = !string.IsNullOrEmpty(sel.PasswordEnc);
        if (hasSaved) password = CredentialProtector.TryUnprotect(sel.PasswordEnc!);

        if (password == null) // not saved, or blob no longer decryptable
        {
            var res = PasswordPrompt.Ask(this, sel, hasSaved);
            if (res == null) return;
            password = res.Value.Password;

            if (res.Value.Remember)
            {
                sel.PasswordEnc = CredentialProtector.Protect(password);
                _store.Update(sel);
                RefreshList();
            }
            else if (hasSaved)
            {
                sel.PasswordEnc = null;
                _store.Update(sel);
                RefreshList();
            }
        }

        OpenSession(sel, password);
    }

    private void OpenSession(Connection conn, string password)
    {
        var page = new TabPage(conn.ToString());
        var session = new RdpSessionControl(conn, password) { Dock = DockStyle.Fill };
        session.StateChanged += (_, _) => { if (!IsDisposed) _tabs.Invalidate(); };
        session.CloseRequested += (_, _) => RemoveTab(page);

        page.Tag = session;
        page.Controls.Add(session);
        _tabs.TabPages.Add(page);
        _tabs.SelectedTab = page; // shown now, so the control gets a handle and connects
        _tabs.Invalidate();
    }

    private void RemoveTab(TabPage page)
    {
        if (page.Tag is RdpSessionControl s) s.Disconnect();
        _tabs.TabPages.Remove(page);
        page.Dispose();
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        foreach (TabPage page in _tabs.TabPages)
            if (page.Tag is RdpSessionControl s) s.Disconnect();
        base.OnFormClosing(e);
    }
}
