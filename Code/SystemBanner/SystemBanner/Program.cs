//Copyright (c) 2023, Aaron Wawrzyniak. MIT License Applies.
//Windows XP port, logon screen banner, watchdog and live updates: Copyright (c) 2026, Cole. MIT License Applies.
using System;
using System.Windows.Forms;
using Microsoft.Win32;

namespace SystemBanner
{
    internal static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        /// 
        //debug var for console and event log entries
        public static bool debug;
        public static bool bannerTop = false;
        public static bool bannerBottom = true;
        public static bool bannerTopAndBottom;
        //storage for initial values to detect changes later
        public static int displayCount = System.Windows.Forms.Screen.AllScreens.Length;
        public static int displayPixelLength;
        public static int displayPixelHeight;
        public static int displayPixelHash;
        public static int[] oldBannerColor;
        public static string oldBannerText;
        public static bool oldBannerTopAndBottom;
        //stock classifications, by system; the code is the value of the Simple setting, 1 to 6 for the United States as before,
        //then a range of ten per system; national colors are used where an official text sets them, NATO follows a common unofficial convention, the others are neutral
        //(white on black, so they cannot be taken for the black on white unconfigured banner)
        public static int[] unconfiguredBannerColor = new int[6] { 255, 255, 255, 0, 0, 0 };
        public static string unconfiguredBannerText = "Classification is not configured.";
        public class Preset
        {
            public int Code; //value of the Simple setting
            public string ClassificationSystem;
            public string Text;
            public int[] Colors; //background red, green, blue, then text red, green, blue, same order as the "0" to "5" registry values
            public Preset(int code, string classificationSystem, string text, int[] colors)
            {
                Code = code;
                ClassificationSystem = classificationSystem;
                Text = text;
                Colors = colors;
            }
        }
        public static Preset[] presets = new Preset[]
        {
            //United States: gsa form color info collected by Frank Caviggia @ https://github.com/fcaviggia/classification-banner
            new Preset(1, "United States", "UNCLASSIFIED", new int[6] { 0, 122, 51, 255, 255, 255 }),
            new Preset(2, "United States", "CUI", new int[6] { 48, 31, 85, 255, 255, 255 }),
            new Preset(3, "United States", "CONFIDENTIAL", new int[6] { 0, 51, 160, 255, 255, 255 }),
            new Preset(4, "United States", "SECRET", new int[6] { 200, 16, 46, 255, 255, 255 }),
            new Preset(5, "United States", "TOP SECRET", new int[6] { 255, 103, 31, 255, 255, 255 }),
            new Preset(6, "United States", "TOP SECRET//SCI", new int[6] { 247, 234, 72, 0, 0, 0 }),
            //France: decree 2019-1271 and IGI 1300 (2021) stamp SECRET and TRES SECRET in red; DIFFUSION RESTREINTE is a protection mark, not a classification, with no color: neutral
            new Preset(11, "France", "DIFFUSION RESTREINTE", new int[6] { 0, 0, 0, 255, 255, 255 }),
            new Preset(12, "France", "SECRET", new int[6] { 200, 16, 46, 255, 255, 255 }),
            new Preset(13, "France", "TR\u00c8S SECRET", new int[6] { 200, 16, 46, 255, 255, 255 }),
            //Germany: VS-Anweisung annex IV (2023) marks STRENG GEHEIM and GEHEIM in red, with crossed yellow and red stripes for STRENG GEHEIM folders,
            //and a blue stripe for VS-VERTRAULICH; VS-NUR FUER DEN DIENSTGEBRAUCH is marked in black or blue: neutral
            new Preset(21, "Germany", "VS-NUR F\u00dcR DEN DIENSTGEBRAUCH", new int[6] { 0, 0, 0, 255, 255, 255 }),
            new Preset(22, "Germany", "VS-VERTRAULICH", new int[6] { 0, 51, 160, 255, 255, 255 }),
            new Preset(23, "Germany", "GEHEIM", new int[6] { 200, 16, 46, 255, 255, 255 }),
            new Preset(24, "Germany", "STRENG GEHEIM", new int[6] { 200, 16, 46, 247, 234, 72 }),
            //United Kingdom: the Government Security Classifications guidance discourages color coding: neutral
            new Preset(31, "United Kingdom", "OFFICIAL", new int[6] { 0, 0, 0, 255, 255, 255 }),
            new Preset(32, "United Kingdom", "OFFICIAL-SENSITIVE", new int[6] { 0, 0, 0, 255, 255, 255 }),
            new Preset(33, "United Kingdom", "SECRET", new int[6] { 0, 0, 0, 255, 255, 255 }),
            new Preset(34, "United Kingdom", "TOP SECRET", new int[6] { 0, 0, 0, 255, 255, 255 }),
            //NATO: AC/35-D/2002-REV5 sets no colors; common unofficial convention reusing the United States colors (orange for NATO RESTRICTED, yellow for COSMIC TOP SECRET)
            new Preset(41, "NATO", "NATO UNCLASSIFIED", new int[6] { 0, 122, 51, 255, 255, 255 }),
            new Preset(42, "NATO", "NATO RESTRICTED", new int[6] { 255, 103, 31, 255, 255, 255 }),
            new Preset(43, "NATO", "NATO CONFIDENTIAL", new int[6] { 0, 51, 160, 255, 255, 255 }),
            new Preset(44, "NATO", "NATO SECRET", new int[6] { 200, 16, 46, 255, 255, 255 }),
            new Preset(45, "NATO", "COSMIC TOP SECRET", new int[6] { 247, 234, 72, 0, 0, 0 }),
            //United Nations: ST/SGB/2007/6 sets no colors: neutral; "UN" keeps the levels apart from the United States ones
            new Preset(51, "United Nations", "UN CONFIDENTIAL", new int[6] { 0, 0, 0, 255, 255, 255 }),
            new Preset(52, "United Nations", "UN STRICTLY CONFIDENTIAL", new int[6] { 0, 0, 0, 255, 255, 255 })
        };
        public static Preset FindPreset(int code) //null when no stock classification has this code
        {
            foreach (Preset preset in presets)
            {
                if (preset.Code == code)
                {
                    return preset;
                }
            }
            return null;
        }
        //set default color and text as unconfigured in case first run/registry data does not exist
        public static int[] bannerColor = unconfiguredBannerColor;
        public static string bannerText = unconfiguredBannerText;
        //true when banners are drawn on the secure Winlogon desktop (logon screen, lock screen, ctrl+alt+del), see Service.cs
        public static bool secureDesktop;
        //true only while SystemBanner itself closes its banners, so user close attempts (alt+f4, etc.) can be refused
        public static bool closingBanners;
        //held for the life of the process so only one SystemBanner of each kind runs per session
        private static System.Threading.Mutex instanceMutex;

        [STAThread]
        static void Main(string[] args)
        {
            //write any crash with its full stack trace to %TEMP%\SystemBanner_crash.log (C:\WINDOWS\Temp for the service)
            AppDomain.CurrentDomain.UnhandledException += delegate (object sender, UnhandledExceptionEventArgs e) { LogCrash(e.ExceptionObject); };
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
            Application.ThreadException += delegate (object sender, System.Threading.ThreadExceptionEventArgs e) { LogCrash(e.Exception); };
            //"/diag" writes what SystemBanner sees in the registry to SystemBanner_diag.txt on the Desktop, then quits
            if (args.Length > 0 && args[0].ToLower() == "/diag")
            {
                WriteDiagnostics();
                return;
            }
#if WIN2000
            //"/install", "/uninstall" and "/stop": Windows 2000 has no sc.exe, reg.exe nor taskkill.exe, so SystemBanner sets itself up, see Win2000.cs
            if (args.Length > 0 && (args[0].ToLower() == "/install" || args[0].ToLower() == "/uninstall" || args[0].ToLower() == "/stop"))
            {
                Environment.ExitCode = Win2000.Setup(args[0].ToLower());
                return;
            }
#endif
            //"/service" is used by the SystemBanner Windows service (watchdog), see Service.cs
            if (args.Length > 0 && args[0].ToLower() == "/service")
            {
                System.ServiceProcess.ServiceBase.Run(new BannerService());
                return;
            }
            //"/winlogon" is started by the service directly on the secure Winlogon desktop (logon screen, lock screen, ctrl+alt+del)
            string mutexName = @"Local\SystemBanner";
            if (args.Length > 0 && args[0].ToLower() == "/winlogon")
            {
                secureDesktop = true;
                mutexName = @"Local\SystemBannerWinlogon";
                GetRegValues(); //read Debug before logging
                BannerService.AttachToWinlogonDesktop();
            }
            //only one banner per session (the Run key and the service watchdog can both start us)
            bool createdNew;
            instanceMutex = new System.Threading.Mutex(true, mutexName, out createdNew);
            if (!createdNew)
            {
                return;
            }
            InitBanners();
            //on your marks, get set...
            Application.Run();
        }
        public static void InitBanners()
        {
            //store initial display data
            displayPixelLength = 0;
            displayPixelHeight = 0;
            displayPixelHash = 0;
            displayCount = System.Windows.Forms.Screen.AllScreens.Length;
            for (int i = 0; i < System.Windows.Forms.Screen.AllScreens.Length; i++)
            {
                displayPixelLength += System.Windows.Forms.Screen.AllScreens[i].Bounds.Width;
                displayPixelHeight += System.Windows.Forms.Screen.AllScreens[i].Bounds.Height;
                displayPixelHash += System.Windows.Forms.Screen.AllScreens[i].Bounds.GetHashCode();
            }
            //if they exist, grab color and text user configuration from the registry set manually or via group policy
            GetRegValues();
            //store initial color and text
            oldBannerColor = bannerColor;
            oldBannerText = bannerText;
            oldBannerTopAndBottom = bannerTopAndBottom;
            //for each screen that exists, build me a new banner on that screen with color and text values defined.
            BuildBanners();
            //set a timer for refreshing banners if needed
            RefreshBannerTimer();
            //and react right away to classification changes instead of waiting for the timer
            WatchPolicyKey();
        }
        [System.Runtime.InteropServices.DllImport("ADVAPI32")]
        private static extern int RegNotifyChangeKeyValue(IntPtr hKey, bool bWatchSubtree, int dwNotifyFilter, IntPtr hEvent, bool fAsynchronous);
        private const int REG_NOTIFY_CHANGE_NAME_AND_LAST_SET = 0x1 | 0x4; // REG_NOTIFY_CHANGE_NAME | REG_NOTIFY_CHANGE_LAST_SET
        private static void WatchPolicyKey()
        {
            //the banners exist now, so this is the WinForms context of the UI thread
            System.Threading.SynchronizationContext uiContext = System.Threading.SynchronizationContext.Current;
            if (uiContext == null)
            {
                return;
            }
            //on XP a registry notification dies with the thread that asked for it, so keep one thread for it
            System.Threading.Thread watcher = new System.Threading.Thread(delegate ()
            {
                try
                {
#if WIN2000
                    IntPtr policies = Win2000.OpenPoliciesKeyHandle(); //.NET 2.0 RegistryKey has no Handle, open the key with the Win32 API
                    using (var changed = new System.Threading.AutoResetEvent(false))
                    {
                        while (policies != IntPtr.Zero && RegNotifyChangeKeyValue(policies, true, REG_NOTIFY_CHANGE_NAME_AND_LAST_SET, changed.SafeWaitHandle.DangerousGetHandle(), true) == 0)
                        {
                            changed.WaitOne();
                            System.Threading.Thread.Sleep(300); //group policy writes several values in a row, apply them together
                            uiContext.Post(delegate { RefreshBannerTick(null, EventArgs.Empty); }, null);
                        }
                    }
#else
                    using (var policies = OpenPoliciesKey()) //watch the parent, SystemBanner may not exist yet
                    using (var changed = new System.Threading.AutoResetEvent(false))
                    {
                        while (policies != null && RegNotifyChangeKeyValue(policies.Handle.DangerousGetHandle(), true, REG_NOTIFY_CHANGE_NAME_AND_LAST_SET, changed.SafeWaitHandle.DangerousGetHandle(), true) == 0)
                        {
                            changed.WaitOne();
                            System.Threading.Thread.Sleep(300); //group policy writes several values in a row, apply them together
                            uiContext.Post(delegate { RefreshBannerTick(null, EventArgs.Empty); }, null);
                        }
                    }
#endif
                }
                catch (Exception ex) //the 5 sec timer still picks up changes
                {
                    LogEventString("REGISTRY WATCH ERROR " + ex.Message);
                }
            });
            watcher.IsBackground = true;
            watcher.Start();
        }
        public static void GetRegValues()
        {
            string source = "NO VIEW (SystemBanner key not found)";
            bool found = false;
            foreach (RegistryView view in PolicyViews())
            {
                try
                {
                    if (ReadRegValues(view))
                    {
                        source = view + " VIEW";
                        found = true;
                        break;
                    }
                }
                catch (System.Security.SecurityException) //access denied in that view, try the next one
                {
                    source = "NO VIEW (access denied in " + view + " view)";
                }
            }
            if (!found) //show unconfigured instead of crashing or keeping half read values
            {
                bannerColor = unconfiguredBannerColor;
                bannerText = unconfiguredBannerText;
            }
            //log where the settings come from, only when it changes (this runs every 5 sec)
#if WIN2000
            string colorsText = Win2000.Join(bannerColor); //.NET 2.0 has no string.Join for int arrays
#else
            string colorsText = string.Join(",", bannerColor);
#endif
            string summary = "REGISTRY: SETTINGS FROM " + source + ", TEXT=" + bannerText + ", COLORS=" + colorsText + ", TOPANDBOTTOM=" + bannerTopAndBottom;
            if (summary != lastRegistrySummary)
            {
                lastRegistrySummary = summary;
                LogEventString(summary);
            }
        }
        private static string lastRegistrySummary;
        //registry views to look for the policy key, in order: the default view first (Vista x64 refuses the explicit
        //64/32 bit views on HKLM\SOFTWARE\Policies with "access denied" while its default view sees the key), then on
        //64 bit Windows the explicit views, in case the default view of this 32 bit process is redirected to Wow6432Node
        private static RegistryView[] PolicyViews()
        {
#if WIN2000
            return new RegistryView[] { RegistryView.Default }; //Windows 2000 is 32 bit only
#else
            return Environment.Is64BitOperatingSystem ? new RegistryView[] { RegistryView.Default, RegistryView.Registry64, RegistryView.Registry32 } : new RegistryView[] { RegistryView.Default };
#endif
        }
        private static RegistryKey OpenPoliciesKey() //HKLM\SOFTWARE\Policies in the first view that lets us open it, or null
        {
            foreach (RegistryView view in PolicyViews())
            {
                try
                {
#if WIN2000
                    RegistryKey policies = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Policies"); //.NET 2.0 has no registry views
#else
                    RegistryKey policies = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view).OpenSubKey(@"SOFTWARE\Policies");
#endif
                    if (policies != null)
                    {
                        return policies;
                    }
                }
                catch (System.Security.SecurityException)
                {
                    //access denied in that view, try the next one
                }
            }
            return null;
        }
        private static void WriteDiagnostics()
        {
            System.Text.StringBuilder report = new System.Text.StringBuilder();
            report.AppendLine("SystemBanner diagnostics, " + DateTime.Now);
#if WIN2000
            report.AppendLine("Windows: " + Environment.OSVersion + " (Windows 2000 build, 32 bit)");
            report.AppendLine(".NET runtime: " + Environment.Version + ", user: " + Environment.UserDomainName + "\\" + Environment.UserName);
            report.Append(Win2000.ProcessAndServiceReport());
            foreach (RegistryView view in PolicyViews())
#else
            report.AppendLine("Windows: " + Environment.OSVersion + ", 64 bit OS: " + Environment.Is64BitOperatingSystem + ", 64 bit process: " + Environment.Is64BitProcess);
            report.AppendLine(".NET runtime: " + Environment.Version + ", user: " + Environment.UserDomainName + "\\" + Environment.UserName);
            foreach (RegistryView view in new RegistryView[] { RegistryView.Default, RegistryView.Registry64, RegistryView.Registry32 })
#endif
            {
                report.AppendLine();
                report.AppendLine("[" + view + " view] HKLM\\SOFTWARE\\Policies\\SystemBanner");
                try
                {
#if WIN2000
                    RegistryKey hklm = Registry.LocalMachine; //.NET 2.0 has no registry views
#else
                    using (var hklm = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view))
#endif
                    using (var key = hklm.OpenSubKey(@"SOFTWARE\Policies\SystemBanner", RegistryKeyPermissionCheck.ReadSubTree))
                    {
                        if (key == null)
                        {
                            report.AppendLine("  key not found");
                            continue;
                        }
                        foreach (string name in key.GetValueNames())
                        {
                            object value = key.GetValue(name);
                            report.AppendLine("  " + name + " = " + value + " (" + key.GetValueKind(name) + ", " + (value == null ? "null" : value.GetType().Name) + ")");
                        }
                    }
                }
                catch (Exception ex)
                {
                    report.AppendLine("  ERROR: " + ex);
                }
            }
            report.AppendLine();
            try
            {
                GetRegValues();
                report.AppendLine("SystemBanner reads: " + lastRegistrySummary + ", DEBUG=" + debug);
            }
            catch (Exception ex)
            {
                report.AppendLine("SystemBanner read ERROR: " + ex);
            }
            string file = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "SystemBanner_diag.txt");
            System.IO.File.WriteAllText(file, report.ToString());
        }
        private static bool ReadRegValues(RegistryView view) //true when the SystemBanner key exists in that view
        {
            //grab registry key and see if it exists
#if WIN2000
            RegistryKey hklm = Registry.LocalMachine; //.NET 2.0 has no registry views, Windows 2000 is 32 bit only
#else
            using (var hklm = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view))
#endif
            using (var checkKey = hklm.OpenSubKey(@"SOFTWARE\Policies\SystemBanner", RegistryKeyPermissionCheck.ReadSubTree))
            {
                if (checkKey != null)
                {
                    var key = hklm.OpenSubKey(@"SOFTWARE\Policies\SystemBanner", RegistryKeyPermissionCheck.ReadSubTree);
                    //start from a fresh array, writing into bannerColor would overwrite the stock color arrays it points to on a second read
                    bannerColor = (int[])unconfiguredBannerColor.Clone();
                    //values removed since the last read must go back to their defaults
                    bannerText = unconfiguredBannerText;
                    bannerTopAndBottom = false;
                    debug = false;
                    //check DWORD registry values for custom color if they exist, and if so, grab them
                    for (int i = 0; i < bannerColor.Length; i++)
                    {
                        var value = key.GetValue(i.ToString());
                        if ((value != null)) //check reg value against bounds of colors
                        {
                            if (((int)value >= 0) & ((int)value <= 255))
                            {
                                value = key.GetValue(i.ToString());
                                bannerColor[i] = (int)value;
                            }
                        }
                        else
                        {
                            bannerColor[i] = unconfiguredBannerColor[i]; 
                        }

                    }
                    //check SZ registry value for custom text if it exists, and if so, grab it
                    var textValue = key.GetValue("Text");
                    if (textValue != null)
                    {
                        textValue = key.GetValue("Text");
                        bannerText = (string)textValue;
                    }
                    //override custom if simple value is set
                    var simpleValue = key.GetValue("Simple");
                    if (simpleValue != null)
                    {
                        simpleValue = key.GetValue("Simple");
                        Preset preset = FindPreset((int)simpleValue); //null for 0 and unknown codes
                        if (preset != null)
                        {
                            bannerColor = preset.Colors;
                            bannerText = preset.Text;
                        }
                    }
                    //check if debug exists and is 1. If 1 then set debug to true.
                    var debugValue = key.GetValue("Debug");
                    if (debugValue != null)
                    {
                        if ((int)debugValue == 1)
                        {
                            debug = true;
                        }
                    }
                    //check if TopAndBottom exists and is 1. If 1 then set bannerTopAndBottom to true.
                    var bannerTopAndBottomValue = key.GetValue("TopAndBottom");
                    if (bannerTopAndBottomValue != null)
                    {
                        if ((int)bannerTopAndBottomValue == 1)
                        {
                            bannerTopAndBottom = true;
                        }
                    }
                    return true;
                }
                //if no reg values, set to not configured.
                else
                {
                    bannerColor = unconfiguredBannerColor;
                    bannerText = unconfiguredBannerText;
                    return false;
                }
            }
        }
        private static void BuildBanners() 
            //This initially builds the SystemBanner(s) on all available windows.
        {
            for (int i = 0; i < System.Windows.Forms.Screen.AllScreens.Length; i++)
            {
                Banner bannerTopInstance = new Banner(i, bannerTop);
                bannerTopInstance.Show();
                if (bannerTopAndBottom)
                {
                    Banner bannerBottomInstance = new Banner(i, bannerBottom);
                    bannerBottomInstance.Show();
                }

            }
        }
        private static void KillBanners()
        {
            closingBanners = true;
            for (int i = Application.OpenForms.Count - 1; i >= 0; i--)
            {
                Application.OpenForms[i].Close();
            }
            closingBanners = false;
        }
        private static void RebuildBanners()
            //This calls KillBanners() to close all open banners, then calls BuildBanners() again to build new banners based on new display info. 
        {
            KillBanners();
            BuildBanners();
        }
            
        private static void RefreshBannerTimer()
        {
            Timer bannerTimer = new Timer();
            bannerTimer.Interval = (50 * 100); // 5 sec
            bannerTimer.Tick += new EventHandler(RefreshBannerTick);
            bannerTimer.Start();
        }
        private static void RefreshBannerTick(object sender, EventArgs e)
        {
            //pick up classification changes (group policy or manual registry edits) without a restart
            GetRegValues();
            if (secureDesktop && Application.OpenForms.Count == 0) //the Winlogon banners were closed anyway (logoff), bring them back
            {
                BuildBanners();
            }
            if (displayCount != System.Windows.Forms.Screen.AllScreens.Length)
            {
                RebuildBanners();
                displayCount = System.Windows.Forms.Screen.AllScreens.Length;
            }
            int currentDisplayPixelLength = 0;
            int currentDisplayPixelHeight = 0;
            int currentDisplayPixelHash = 0;
            for (int i = 0; i < System.Windows.Forms.Screen.AllScreens.Length; i++)
            {
                currentDisplayPixelLength += System.Windows.Forms.Screen.AllScreens[i].Bounds.Width;
                currentDisplayPixelHeight += System.Windows.Forms.Screen.AllScreens[i].Bounds.Height;
                currentDisplayPixelHash += System.Windows.Forms.Screen.AllScreens[i].Bounds.GetHashCode();
            }
            if (displayPixelLength != currentDisplayPixelLength)
            {
                RebuildBanners();
                displayPixelLength = currentDisplayPixelLength;
            }
            if (displayPixelHeight != currentDisplayPixelHeight)
            {
                RebuildBanners();
                displayPixelHeight = currentDisplayPixelHeight;
            }
            if (displayPixelHash != currentDisplayPixelHash)
            {
                RebuildBanners();
                displayPixelHash = currentDisplayPixelHash;
            }
            //compare contents, GetRegValues hands out a new color array on every read
#if WIN2000
            if (!Win2000.SameColors(oldBannerColor, bannerColor) || oldBannerText != bannerText || oldBannerTopAndBottom != bannerTopAndBottom) //.NET 2.0 has no LINQ
#else
            if (!System.Linq.Enumerable.SequenceEqual(oldBannerColor, bannerColor) || oldBannerText != bannerText || oldBannerTopAndBottom != bannerTopAndBottom)
#endif
            {
                LogEventString("CLASSIFICATION CHANGED TO " + bannerText + ", REBUILDING BANNERS");
                RebuildBanners();
                oldBannerColor = bannerColor;
                oldBannerText = bannerText;
                oldBannerTopAndBottom = bannerTopAndBottom;
            }
        }
        public static void LogEventString(string msg)
        {
            if (debug != true)
            {
                return;
            }
            try
            {
                using (System.Diagnostics.EventLog eventLog = new System.Diagnostics.EventLog("Application"))
                {
                    eventLog.Source = "Application";
                    eventLog.WriteEntry(msg, System.Diagnostics.EventLogEntryType.Information, 1902, 1);
                }
            }
            catch (Exception) //on XP a standard user cannot search the Security log (SecurityException), fall back to a text file
            {
                LogToFile("SystemBanner_debug.log", msg);
            }
        }
        private static void LogCrash(object exception)
        {
            LogToFile("SystemBanner_crash.log", Convert.ToString(exception));
        }
        private static void LogToFile(string fileName, string msg)
        {
            try
            {
                System.IO.File.AppendAllText(System.IO.Path.Combine(System.IO.Path.GetTempPath(), fileName), DateTime.Now + " [" + string.Join(" ", Environment.GetCommandLineArgs()) + "]" + Environment.NewLine + msg + Environment.NewLine + Environment.NewLine);
            }
            catch (Exception)
            {
                //nowhere left to log, never crash because of logging
            }
        }
    }
}
