//Copyright (c) 2026, Aaron Wawrzyniak. MIT License Applies.
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace SystemBanner
{
    //Windows service (SystemBanner.exe /service, runs as LocalSystem) acting as a watchdog every 3 sec:
    // 1. keeps a SystemBanner.exe /winlogon child running on the secure Winlogon desktop (logon screen, locked workstation, ctrl+alt+del)
    // 2. restarts the user mode banner in every active user session if it is closed or killed
    //Written for Windows XP (no session 0 isolation).
    internal class BannerService : System.ServiceProcess.ServiceBase
    {
        private System.Threading.Timer watchdogTimer;
        private static System.Diagnostics.Process winlogonBanner;

        public BannerService()
        {
            this.ServiceName = "SystemBanner";
            this.CanStop = true;
        }

        protected override void OnStart(string[] args)
        {
            Program.GetRegValues(); //picks up the Debug value so the service logs too
            Program.LogEventString("SERVICE: STARTED AS " + System.Security.Principal.WindowsIdentity.GetCurrent().Name);
            watchdogTimer = new System.Threading.Timer(WatchdogTick, null, 0, 3000);
        }

        protected override void OnStop()
        {
            watchdogTimer.Dispose();
            lock (typeof(BannerService))
            {
                if (winlogonBanner != null && !winlogonBanner.HasExited)
                {
                    winlogonBanner.Kill();
                }
            }
        }

        #region SECURE DESKTOP

        [DllImport("USER32", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);
        [DllImport("USER32", SetLastError = true)]
        private static extern bool SetThreadDesktop(IntPtr hDesktop);
        [DllImport("USER32", SetLastError = true)]
        private static extern IntPtr GetThreadDesktop(int dwThreadId);
        [DllImport("USER32", SetLastError = true)]
        private static extern IntPtr OpenInputDesktop(uint dwFlags, bool fInherit, uint dwDesiredAccess);
        [DllImport("USER32")]
        private static extern bool CloseDesktop(IntPtr hDesktop);
        [DllImport("USER32", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool GetUserObjectInformation(IntPtr hObj, int nIndex, System.Text.StringBuilder pvInfo, int nLength, out int lpnLengthNeeded);
        [DllImport("KERNEL32")]
        private static extern int GetCurrentThreadId();
        private const uint MAXIMUM_ALLOWED = 0x02000000;
        private const uint DESKTOP_READOBJECTS = 0x0001;
        private const int UOI_NAME = 2;

        //called first thing by SystemBanner.exe /winlogon (before any window exists), makes sure the banners are created on the Winlogon desktop
        public static void AttachToWinlogonDesktop()
        {
            if (!DesktopName(GetThreadDesktop(GetCurrentThreadId())).Equals("Winlogon", StringComparison.OrdinalIgnoreCase))
            {
                IntPtr desktop = OpenDesktop("Winlogon", 0, false, MAXIMUM_ALLOWED);
                if (desktop == IntPtr.Zero || !SetThreadDesktop(desktop))
                {
                    Program.LogEventString("WINLOGON BANNER: CANNOT ATTACH TO WINLOGON DESKTOP, ERROR " + Marshal.GetLastWin32Error());
                }
            }
            Program.LogEventString("WINLOGON BANNER: RUNNING ON DESKTOP " + DesktopName(GetThreadDesktop(GetCurrentThreadId())));
        }

        //true when the Winlogon desktop is the one on screen (logon screen, locked workstation, ctrl+alt+del)
        public static bool IsWinlogonInputDesktop()
        {
            IntPtr input = OpenInputDesktop(0, false, DESKTOP_READOBJECTS);
            if (input == IntPtr.Zero)
            {
                return false;
            }
            string name = DesktopName(input);
            CloseDesktop(input);
            return name.Equals("Winlogon", StringComparison.OrdinalIgnoreCase);
        }

        private static string DesktopName(IntPtr desktop)
        {
            System.Text.StringBuilder name = new System.Text.StringBuilder(256);
            int needed;
            GetUserObjectInformation(desktop, UOI_NAME, name, name.Capacity * 2, out needed);
            return name.ToString();
        }

        #endregion

        #region WATCHDOG

        [StructLayout(LayoutKind.Sequential)]
        private struct WTS_SESSION_INFO
        {
            public int SessionID;
            public IntPtr pWinStationName;
            public int State;
        }
        private const int WTSActive = 0;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct STARTUPINFO
        {
            public int cb;
            public string lpReserved;
            public string lpDesktop;
            public string lpTitle;
            public int dwX;
            public int dwY;
            public int dwXSize;
            public int dwYSize;
            public int dwXCountChars;
            public int dwYCountChars;
            public int dwFillAttribute;
            public int dwFlags;
            public short wShowWindow;
            public short cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public int dwProcessId;
            public int dwThreadId;
        }
        private const uint CREATE_UNICODE_ENVIRONMENT = 0x00000400;

        [DllImport("WTSAPI32", SetLastError = true)]
        private static extern bool WTSEnumerateSessions(IntPtr hServer, int reserved, int version, out IntPtr ppSessionInfo, out int pCount);
        [DllImport("WTSAPI32")]
        private static extern void WTSFreeMemory(IntPtr pMemory);
        [DllImport("WTSAPI32", SetLastError = true)]
        private static extern bool WTSQueryUserToken(int sessionId, out IntPtr phToken);
        [DllImport("USERENV", SetLastError = true)]
        private static extern bool CreateEnvironmentBlock(out IntPtr lpEnvironment, IntPtr hToken, bool bInherit);
        [DllImport("USERENV", SetLastError = true)]
        private static extern bool DestroyEnvironmentBlock(IntPtr lpEnvironment);
        [DllImport("ADVAPI32", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CreateProcessAsUser(IntPtr hToken, string lpApplicationName, System.Text.StringBuilder lpCommandLine, IntPtr lpProcessAttributes, IntPtr lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);
        [DllImport("KERNEL32", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CreateProcess(string lpApplicationName, System.Text.StringBuilder lpCommandLine, IntPtr lpProcessAttributes, IntPtr lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);
        [DllImport("KERNEL32", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr hObject);

        private void WatchdogTick(object state)
        {
            try //an exception on a timer thread would kill the service
            {
                lock (typeof(BannerService)) //ticks must not overlap
                {
                    CheckWinlogonBanner();
                    CheckUserBanners();
                }
            }
            catch (Exception ex)
            {
                Program.LogEventString("SERVICE: WATCHDOG ERROR " + ex.Message);
            }
        }

        private static void CheckWinlogonBanner()
        {
            if (winlogonBanner != null && !winlogonBanner.HasExited)
            {
                return;
            }
            //started as LocalSystem directly on the Winlogon desktop, so all its windows live there
            STARTUPINFO si = new STARTUPINFO();
            si.cb = Marshal.SizeOf(si);
            si.lpDesktop = @"winsta0\winlogon";
            PROCESS_INFORMATION pi;
            string exe = Application.ExecutablePath;
            if (CreateProcess(exe, new System.Text.StringBuilder("\"" + exe + "\" /winlogon"), IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, System.IO.Path.GetDirectoryName(exe), ref si, out pi))
            {
                winlogonBanner = System.Diagnostics.Process.GetProcessById(pi.dwProcessId);
                CloseHandle(pi.hProcess);
                CloseHandle(pi.hThread);
                Program.LogEventString("SERVICE: WINLOGON BANNER STARTED");
            }
            else
            {
                Program.LogEventString("SERVICE: CANNOT START WINLOGON BANNER, ERROR " + Marshal.GetLastWin32Error());
            }
        }

        private static void CheckUserBanners()
        {
            IntPtr sessions;
            int count;
            if (!WTSEnumerateSessions(IntPtr.Zero, 0, 1, out sessions, out count))
            {
                return;
            }
            try
            {
                int size = Marshal.SizeOf(typeof(WTS_SESSION_INFO));
                for (int i = 0; i < count; i++)
                {
                    WTS_SESSION_INFO session = (WTS_SESSION_INFO)Marshal.PtrToStructure(new IntPtr(sessions.ToInt64() + (i * size)), typeof(WTS_SESSION_INFO));
                    //only sessions with a logged on user whose shell is up (the AppBar needs explorer)
                    if (session.State == WTSActive && SessionRuns(session.SessionID, "explorer") && !SessionRuns(session.SessionID, null))
                    {
                        StartBannerInSession(session.SessionID);
                    }
                }
            }
            finally
            {
                WTSFreeMemory(sessions);
            }
        }

        private static bool SessionRuns(int sessionId, string processName) //null processName = a user mode SystemBanner (not this service nor the Winlogon banner, which share session 0 with the first XP user)
        {
            System.Diagnostics.Process current = System.Diagnostics.Process.GetCurrentProcess();
            int winlogonId = (winlogonBanner != null) ? winlogonBanner.Id : -1;
            foreach (System.Diagnostics.Process p in System.Diagnostics.Process.GetProcessesByName(processName ?? current.ProcessName))
            {
                if (p.SessionId == sessionId && p.Id != current.Id && p.Id != winlogonId)
                {
                    return true;
                }
            }
            return false;
        }

        private static void StartBannerInSession(int sessionId)
        {
            IntPtr userToken;
            if (!WTSQueryUserToken(sessionId, out userToken))
            {
                Program.LogEventString("SERVICE: NO USER TOKEN FOR SESSION " + sessionId + ", ERROR " + Marshal.GetLastWin32Error());
                return;
            }
            IntPtr environment = IntPtr.Zero;
            try
            {
                CreateEnvironmentBlock(out environment, userToken, false);
                STARTUPINFO si = new STARTUPINFO();
                si.cb = Marshal.SizeOf(si);
                si.lpDesktop = @"winsta0\default"; //the user's normal desktop
                PROCESS_INFORMATION pi;
                string exe = Application.ExecutablePath;
                if (CreateProcessAsUser(userToken, exe, new System.Text.StringBuilder("\"" + exe + "\""), IntPtr.Zero, IntPtr.Zero, false, CREATE_UNICODE_ENVIRONMENT, environment, System.IO.Path.GetDirectoryName(exe), ref si, out pi))
                {
                    CloseHandle(pi.hProcess);
                    CloseHandle(pi.hThread);
                    Program.LogEventString("SERVICE: BANNER STARTED IN SESSION " + sessionId);
                }
                else
                {
                    Program.LogEventString("SERVICE: CANNOT START BANNER IN SESSION " + sessionId + ", ERROR " + Marshal.GetLastWin32Error());
                }
            }
            finally
            {
                if (environment != IntPtr.Zero)
                {
                    DestroyEnvironmentBlock(environment);
                }
                CloseHandle(userToken);
            }
        }

        #endregion
    }
}
