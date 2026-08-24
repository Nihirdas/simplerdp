using System.ComponentModel;
using System.Drawing;
using System.Windows.Forms;
using SimpleRDP.Models;

namespace SimpleRDP.UI;

public enum RdpSessionState { Connecting, Connected, Disconnected }

/// <summary>
/// Hosts one Microsoft RDP ActiveX control (mstscax) and manages its lifecycle.
/// One instance per open tab.
/// </summary>
public class RdpSessionControl : UserControl
{
    private readonly Connection _conn;
    private readonly string _password;

    private AxMSTSCLib.AxMsRdpClient9NotSafeForScripting? _rdp;
    private Panel? _overlay;
    private bool _started;

    public RdpSessionState State { get; private set; } = RdpSessionState.Connecting;

    /// <summary>The connection this session was opened from (for tab styling).</summary>
    public Connection Conn => _conn;

    /// <summary>Raised whenever <see cref="State"/> changes (on the UI thread).</summary>
    public event EventHandler? StateChanged;

    /// <summary>Raised when the session drops; the string is a human-readable reason.</summary>
    public event EventHandler<string>? Disconnected;

    /// <summary>Raised when the user clicks "Close tab" on the disconnect overlay.</summary>
    public event EventHandler? CloseRequested;

    public RdpSessionControl(Connection conn, string password)
    {
        _conn = conn;
        _password = password;
        Dock = DockStyle.Fill;
        BackColor = Color.Black;
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        if (_started) return;
        _started = true;
        Connect();
    }

    public void Connect()
    {
        HideOverlay();
        SetState(RdpSessionState.Connecting);
        try
        {
            if (_rdp == null)
            {
                _rdp = new AxMSTSCLib.AxMsRdpClient9NotSafeForScripting { Dock = DockStyle.Fill };
                ((ISupportInitialize)_rdp).BeginInit();
                Controls.Add(_rdp);
                ((ISupportInitialize)_rdp).EndInit();
                _rdp.OnConnected += (_, _) => SetState(RdpSessionState.Connected);
                _rdp.OnDisconnected += Rdp_OnDisconnected;
            }

            _rdp.Server = _conn.Host;
            _rdp.AdvancedSettings9.RDPPort = _conn.Port;
            if (!string.IsNullOrWhiteSpace(_conn.Username)) _rdp.UserName = _conn.Username;
            if (!string.IsNullOrEmpty(_password)) _rdp.AdvancedSettings9.ClearTextPassword = _password;

            _rdp.AdvancedSettings9.SmartSizing = !_conn.UseAllMonitors;
            // UseMultimon lives on IMsRdpClientNonScriptable5, reached via the OCX.
            if (_conn.UseAllMonitors && _rdp.GetOcx() is MSTSCLib.IMsRdpClientNonScriptable5 ocx)
                ocx.UseMultimon = true;
            _rdp.AdvancedSettings9.EnableCredSspSupport = true;
            _rdp.AdvancedSettings9.AuthenticationLevel = 0; // warn, don't block, on cert mismatch

            var w = _conn.Screen.Mode == "fixed" ? _conn.Screen.Width : Math.Max(ClientSize.Width, 1024);
            var h = _conn.Screen.Mode == "fixed" ? _conn.Screen.Height : Math.Max(ClientSize.Height, 720);
            _rdp.DesktopWidth = w;
            _rdp.DesktopHeight = h;

            _rdp.Connect();
        }
        catch (Exception ex)
        {
            ShowOverlay("Could not start session: " + ex.Message);
            SetState(RdpSessionState.Disconnected);
        }
    }

    public void Disconnect()
    {
        try
        {
            if (_rdp != null && _rdp.Connected != 0) _rdp.Disconnect();
        }
        catch
        {
            // Control may already be torn down; nothing useful to do.
        }
    }

    private void SetState(RdpSessionState state)
    {
        State = state;
        if (!IsDisposed) StateChanged?.Invoke(this, EventArgs.Empty);
    }

    private void Rdp_OnDisconnected(object? sender, AxMSTSCLib.IMsTscAxEvents_OnDisconnectedEvent e)
    {
        var reason = DescribeReason(e.discReason);
        ShowOverlay("Disconnected — " + reason);
        SetState(RdpSessionState.Disconnected);
        Disconnected?.Invoke(this, reason);
    }

    private string DescribeReason(int discReason)
    {
        try
        {
            var ext = _rdp?.ExtendedDisconnectReason ?? 0;
            var msg = _rdp?.GetErrorDescription((uint)discReason, (uint)(int)ext);
            if (!string.IsNullOrWhiteSpace(msg)) return msg!;
        }
        catch
        {
            // fall through to the numeric code
        }
        return "code " + discReason;
    }

    private void ShowOverlay(string message)
    {
        HideOverlay();

        _overlay = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(20, 24, 33) };

        var msg = new Label
        {
            Text = message,
            ForeColor = Color.Gainsboro,
            Dock = DockStyle.Top,
            Height = 64,
            TextAlign = ContentAlignment.MiddleCenter,
            Font = new Font(Font.FontFamily, 10f)
        };

        var reconnect = new Button { Text = "Reconnect", AutoSize = true, Margin = new Padding(6) };
        reconnect.Click += (_, _) => Connect();
        var close = new Button { Text = "Close tab", AutoSize = true, Margin = new Padding(6) };
        close.Click += (_, _) => CloseRequested?.Invoke(this, EventArgs.Empty);

        var actions = new FlowLayoutPanel
        {
            Dock = DockStyle.Top,
            Height = 48,
            FlowDirection = FlowDirection.LeftToRight,
            Padding = new Padding(0, 6, 0, 0)
        };
        actions.Controls.Add(reconnect);
        actions.Controls.Add(close);

        _overlay.Controls.Add(actions); // added first -> sits below msg
        _overlay.Controls.Add(msg);     // added after -> docks to the very top

        Controls.Add(_overlay);
        _overlay.BringToFront();
    }

    private void HideOverlay()
    {
        if (_overlay == null) return;
        Controls.Remove(_overlay);
        _overlay.Dispose();
        _overlay = null;
    }
}
