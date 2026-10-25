using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace DesktopCompanionLauncher
{
    static class Program
    {
        private static NotifyIcon trayIcon;
        private static ContextMenuStrip trayMenu;
        private static Process engineProcess;
        private static bool isCompanionVisible = true;
        private static bool isPerchEnabled = true;
        private static ToolStripMenuItem perchMenuItem;
        private const int UDP_PORT = 48291;
        private static Mutex singleInstanceMutex;
        private static string appDir;

        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            appDir = AppDomain.CurrentDomain.BaseDirectory;

            bool createdNew;
            singleInstanceMutex = new Mutex(true, "DesktopCompanion_TrayLauncher_Mutex", out createdNew);
            if (!createdNew)
            {
                SendCommand("RESET_POSITION");
                SendCommand("SHOW_WINDOW");
                return;
            }

            try
            {
                SetupTray();
                if (StartCompanionEngine())
                {
                    StartWindowTracker();
                    try
                    {
                        trayIcon.ShowBalloonTip(3000, "Desktop Companion", "✦ Desktop Companion is now running!\nLook for me on the bottom right of your desktop.", ToolTipIcon.Info);
                    }
                    catch { }
                    Application.Run();
                }
            }
            finally
            {
                Cleanup();
            }
        }

        private static void SetupTray()
        {
            trayMenu = new ContextMenuStrip();
            trayMenu.Font = new Font("Segoe UI", 9.5f);

            var titleItem = new ToolStripMenuItem("✦ Desktop Companion");
            titleItem.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            titleItem.Enabled = false;
            trayMenu.Items.Add(titleItem);
            trayMenu.Items.Add(new ToolStripSeparator());

            var showItem = new ToolStripMenuItem("👁 Show / Hide Companion", null, (s, e) => ToggleVisibility());
            var headpatItem = new ToolStripMenuItem("💖 Headpat / Pet", null, (s, e) => SendCommand("HEADPAT"));
            perchMenuItem = new ToolStripMenuItem("🪟 Window Perching: ON", null, (s, e) => TogglePerch());
            var chatItem = new ToolStripMenuItem("💬 Open Chat (Enter)", null, (s, e) => SendCommand("TOGGLE_CHAT"));
            var outfitItem = new ToolStripMenuItem("👗 Next Outfit / Model", null, (s, e) => SendCommand("NEXT_MODEL"));
            var gravityItem = new ToolStripMenuItem("🌍 Toggle Gravity (Drop / Float)", null, (s, e) => SendCommand("TOGGLE_GRAVITY"));
            var focusItem = new ToolStripMenuItem("⏱ Pomodoro Focus Timer (25m)", null, (s, e) => SendCommand("TOGGLE_FOCUS"));
            var soundItem = new ToolStripMenuItem("🔊 Toggle Sound Effects", null, (s, e) => SendCommand("TOGGLE_SOUND"));

            trayMenu.Items.Add(showItem);
            trayMenu.Items.Add(headpatItem);
            trayMenu.Items.Add(perchMenuItem);
            trayMenu.Items.Add(chatItem);
            trayMenu.Items.Add(outfitItem);
            trayMenu.Items.Add(gravityItem);
            trayMenu.Items.Add(focusItem);
            trayMenu.Items.Add(soundItem);
            trayMenu.Items.Add(new ToolStripSeparator());

            var openFolderItem = new ToolStripMenuItem("📂 Open Folder", null, (s, e) => Process.Start("explorer.exe", appDir));
            var exitItem = new ToolStripMenuItem("❌ Exit Companion", null, (s, e) => ExitApplication());

            trayMenu.Items.Add(openFolderItem);
            trayMenu.Items.Add(new ToolStripSeparator());
            trayMenu.Items.Add(exitItem);

            trayIcon = new NotifyIcon();
            trayIcon.Text = "Desktop Companion";
            trayIcon.ContextMenuStrip = trayMenu;

            string iconPath = Path.Combine(appDir, "assets", "app_icon.ico");
            if (File.Exists(iconPath))
            {
                try { trayIcon.Icon = new Icon(iconPath); } catch { trayIcon.Icon = SystemIcons.Application; }
            }
            else
            {
                trayIcon.Icon = SystemIcons.Application;
            }

            trayIcon.DoubleClick += (s, e) => ToggleVisibility();
            trayIcon.Visible = true;
        }

        private static void ToggleVisibility()
        {
            isCompanionVisible = !isCompanionVisible;
            SendCommand(isCompanionVisible ? "SHOW_WINDOW" : "HIDE_WINDOW");
        }

        private static void SendCommand(string command)
        {
            try
            {
                using (var client = new UdpClient())
                {
                    byte[] data = Encoding.UTF8.GetBytes(command);
                    client.Send(data, data.Length, "127.0.0.1", UDP_PORT);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("UDP Send Error: " + ex.Message);
            }
        }

        private static string FindEnginePath()
        {
            // 1. Check local bin/
            string[] localCandidates = new string[]
            {
                Path.Combine(appDir, "bin", "DesktopCompanionRuntime.exe"),
                Path.Combine(appDir, "bin", "Godot.exe"),
                Path.Combine(appDir, "bin", "Godot_v4.7.2-stable_win64.exe"),
                Path.Combine(appDir, "bin", "Godot_v4.7.2-stable_win64_console.exe"),
                Path.Combine(appDir, "Godot.exe"),
                Path.Combine(appDir, "DesktopCompanionRuntime.exe"),
                @"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe",
                @"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
            };

            foreach (var path in localCandidates)
            {
                if (File.Exists(path)) return path;
            }

            // 2. Check PATH
            var envPath = Environment.GetEnvironmentVariable("PATH");
            if (envPath != null)
            {
                foreach (var p in envPath.Split(';'))
                {
                    try
                    {
                        var candidate = Path.Combine(p.Trim(), "godot.exe");
                        if (File.Exists(candidate)) return candidate;
                    }
                    catch { }
                }
            }

            return null;
        }

        private static bool StartCompanionEngine()
        {
            string engineExe = FindEnginePath();
            if (string.IsNullOrEmpty(engineExe))
            {
                var result = MessageBox.Show(
                    "Desktop Companion portable runtime engine was not found.\n\nWould you like to automatically download the lightweight Godot runtime (~55MB) now?",
                    "Desktop Companion - First Time Setup",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Information);

                if (result == DialogResult.Yes)
                {
                    engineExe = DownloadPortableEngine();
                    if (string.IsNullOrEmpty(engineExe))
                    {
                        MessageBox.Show("Could not download the engine runtime. Please check your internet connection.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        return false;
                    }
                }
                else
                {
                    return false;
                }
            }

            try
            {
                // Kill any existing stale companion processes
                string[] staleNames = new string[] { "Godot_v4.7.2-stable_win64", "Godot_v4.7.2-stable_win64_console", "DesktopCompanionRuntime", "Godot" };
                foreach (var name in staleNames)
                {
                    foreach (var p in Process.GetProcessesByName(name))
                    {
                        try { p.Kill(); } catch { }
                    }
                }

                var psi = new ProcessStartInfo();
                psi.FileName = engineExe;
                psi.Arguments = "--path \"" + appDir.TrimEnd('\\', '/') + "\"";
                psi.WorkingDirectory = appDir;
                psi.UseShellExecute = false;
                psi.CreateNoWindow = false;
                psi.WindowStyle = ProcessWindowStyle.Normal;

                engineProcess = new Process();
                engineProcess.StartInfo = psi;
                engineProcess.EnableRaisingEvents = true;
                engineProcess.Exited += (s, e) =>
                {
                    // Engine exited from in-game quit: close tray
                    trayIcon.Visible = false;
                    Application.Exit();
                };

                engineProcess.Start();
                return true;
            }
            catch (Exception ex)
            {
                MessageBox.Show("Failed to launch companion engine:\n" + ex.Message, "Launch Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return false;
            }
        }

        private static string DownloadPortableEngine()
        {
            string binDir = Path.Combine(appDir, "bin");
            Directory.CreateDirectory(binDir);
            string zipPath = Path.Combine(binDir, "godot_temp.zip");
            string targetExe = Path.Combine(binDir, "Godot.exe");

            try
            {
                using (var progressForm = new Form())
                {
                    progressForm.Text = "Desktop Companion - Downloading Runtime";
                    progressForm.Size = new Size(420, 150);
                    progressForm.StartPosition = FormStartPosition.CenterScreen;
                    progressForm.FormBorderStyle = FormBorderStyle.FixedDialog;
                    progressForm.MaximizeBox = false;

                    var lbl = new Label() { Text = "Downloading engine runtime (one-time setup)...", AutoSize = true, Location = new Point(20, 20) };
                    var pb = new ProgressBar() { Location = new Point(20, 50), Size = new Size(360, 25), Style = ProgressBarStyle.Continuous };
                    progressForm.Controls.Add(lbl);
                    progressForm.Controls.Add(pb);

                    using (var wc = new WebClient())
                    {
                        wc.DownloadProgressChanged += (s, e) =>
                        {
                            pb.Value = e.ProgressPercentage;
                            lbl.Text = string.Format("Downloading runtime: {0}% ({1:0.0}MB / {2:0.0}MB)",
                                e.ProgressPercentage,
                                e.BytesReceived / 1048576.0,
                                e.TotalBytesToReceive / 1048576.0);
                        };

                        bool completed = false;
                        wc.DownloadFileCompleted += (s, e) =>
                        {
                            completed = true;
                            progressForm.Close();
                        };

                        progressForm.Shown += (s, e) =>
                        {
                            // Official Godot stable Windows 64-bit build
                            string url = "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_win64.exe.zip";
                            wc.DownloadFileAsync(new Uri(url), zipPath);
                        };

                        progressForm.ShowDialog();
                    }

                    if (File.Exists(zipPath))
                    {
                        ZipFile.ExtractToDirectory(zipPath, binDir);
                        File.Delete(zipPath);

                        foreach (var f in Directory.GetFiles(binDir, "*.exe"))
                        {
                            if (!f.Equals(targetExe, StringComparison.OrdinalIgnoreCase))
                            {
                                if (File.Exists(targetExe)) File.Delete(targetExe);
                                File.Move(f, targetExe);
                                break;
                            }
                        }

                        if (File.Exists(targetExe)) return targetExe;
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("Download failed: " + ex.Message);
            }

            return null;
        }

        private static void TogglePerch()
        {
            isPerchEnabled = !isPerchEnabled;
            if (perchMenuItem != null)
            {
                perchMenuItem.Text = isPerchEnabled ? "🪟 Window Perching: ON" : "🪟 Window Perching: OFF";
            }
            SendCommand("TOGGLE_PERCH");
        }

        #region Win32 Window Topology Tracking
        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool IsIconic(IntPtr hWnd);

        [DllImport("dwmapi.dll")]
        private static extern int DwmGetWindowAttribute(IntPtr hwnd, int dwAttribute, out RECT pvAttribute, int cbAttribute);

        [DllImport("user32.dll")]
        private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

        private const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        private static System.Threading.Timer windowTrackerTimer;
        private static IntPtr lastTrackedHwnd = IntPtr.Zero;
        private static RECT lastTrackedRect = new RECT();
        private static string lastTrackedProc = "";
        private static string lastTrackedTitle = "";

        private static void StartWindowTracker()
        {
            windowTrackerTimer = new System.Threading.Timer(TrackForegroundWindow, null, 1200, 200);
        }

        private static int trackerTick = 0;

        private static void TrackForegroundWindow(object state)
        {
            trackerTick++;
            if (trackerTick % 5 == 0)
            {
                EnforceTopMost();
            }

            if (!isPerchEnabled) return;

            try
            {
                IntPtr fg = GetForegroundWindow();
                if (fg == IntPtr.Zero || IsIconic(fg) || !IsWindowVisible(fg))
                {
                    if (lastTrackedHwnd != IntPtr.Zero)
                    {
                        lastTrackedHwnd = IntPtr.Zero;
                        SendCommand("PERCH:NONE:Desktop:Desktop");
                    }
                    return;
                }

                uint pid;
                GetWindowThreadProcessId(fg, out pid);
                if (pid == 0) return;

                // Skip our own engine / launcher
                if (engineProcess != null && !engineProcess.HasExited && pid == (uint)engineProcess.Id)
                    return;
                if (pid == (uint)Process.GetCurrentProcess().Id)
                    return;

                string procName = "";
                try { procName = Process.GetProcessById((int)pid).ProcessName; } catch { return; }

                string lowerProc = procName.ToLowerInvariant();
                if (lowerProc == "progman" || lowerProc == "workerw" || lowerProc == "shellexperiencehost" || lowerProc == "searchhost" || lowerProc == "startmenuexperiencehost")
                {
                    if (lastTrackedHwnd != IntPtr.Zero)
                    {
                        lastTrackedHwnd = IntPtr.Zero;
                        SendCommand("PERCH:NONE:Desktop:Desktop");
                    }
                    return;
                }

                var sb = new StringBuilder(256);
                GetWindowText(fg, sb, 256);
                string title = sb.ToString();
                if (string.IsNullOrWhiteSpace(title)) return;

                RECT r;
                int hr = DwmGetWindowAttribute(fg, DWMWA_EXTENDED_FRAME_BOUNDS, out r, Marshal.SizeOf(typeof(RECT)));
                if (hr != 0) GetWindowRect(fg, out r);

                int w = r.Right - r.Left;
                int h = r.Bottom - r.Top;

                // Ignore tiny popups
                if (w < 260 || h < 200) return;

                // Check change delta
                bool changed = (fg != lastTrackedHwnd) ||
                               Math.Abs(r.Left - lastTrackedRect.Left) > 3 ||
                               Math.Abs(r.Top - lastTrackedRect.Top) > 3 ||
                               Math.Abs(w - (lastTrackedRect.Right - lastTrackedRect.Left)) > 3 ||
                               Math.Abs(h - (lastTrackedRect.Bottom - lastTrackedRect.Top)) > 3;

                if (changed)
                {
                    lastTrackedHwnd = fg;
                    lastTrackedRect = r;
                    lastTrackedProc = procName;
                    lastTrackedTitle = title;

                    string safeTitle = title.Replace(":", " ").Replace("\n", " ").Replace("\r", " ").Trim();
                    if (safeTitle.Length > 60) safeTitle = safeTitle.Substring(0, 60);

                    string msg = string.Format("PERCH:{0},{1},{2},{3}:{4}:{5}", r.Left, r.Top, w, h, procName, safeTitle);
                    SendCommand(msg);
                }
            }
            catch
            {
                // Never crash the background thread
            }
        }

        private static void EnforceTopMost()
        {
            try
            {
                if (engineProcess == null || engineProcess.HasExited) return;
                uint pid = (uint)engineProcess.Id;

                EnumWindows((hWnd, lParam) =>
                {
                    uint p;
                    GetWindowThreadProcessId(hWnd, out p);
                    if (p == pid && IsWindowVisible(hWnd))
                    {
                        SetWindowPos(hWnd, new IntPtr(-1), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010 | 0x0040);
                    }
                    return true;
                }, IntPtr.Zero);
            }
            catch { }
        }
        #endregion

        private static void ExitApplication()
        {
            SendCommand("QUIT");
            Thread.Sleep(250);
            Cleanup();
            Application.Exit();
        }

        private static void Cleanup()
        {
            if (windowTrackerTimer != null)
            {
                try { windowTrackerTimer.Dispose(); } catch { }
            }

            if (trayIcon != null)
            {
                trayIcon.Visible = false;
                trayIcon.Dispose();
            }

            if (engineProcess != null && !engineProcess.HasExited)
            {
                try { engineProcess.Kill(); } catch { }
            }

            if (singleInstanceMutex != null)
            {
                try { singleInstanceMutex.ReleaseMutex(); } catch { }
            }
        }
    }
}
