//Copyright (c) 2023, Aaron Wawrzyniak. MIT License Applies.
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
        //defines stock colors for basic us gov classification based on gsa form color info collected by Frank Caviggia @ https://github.com/fcaviggia/classification-banner
        public static int[] unconfiguredBannerColor = new int[6] { 255, 255, 255, 0, 0, 0 };
        public static int[] unclassifiedBannerColor = new int[6] { 0, 122, 51, 255, 255, 255 };
        public static int[] cuiBannerColor = new int[6] { 48, 31, 85, 255, 255, 255 };
        public static int[] confidentialBannerColor = new int[6] { 0, 51, 160, 255, 255, 255 };
        public static int[] secretBannerColor = new int[6] { 200, 16, 46, 255, 255, 255 };
        public static int[] topsecretBannerColor = new int[6] { 255, 103, 31, 255, 255, 255 };
        public static int[] topsecretsciBannerColor = new int[6] { 247, 234, 72, 0, 0, 0 };
        public static string unconfiguredBannerText = "Classification is not configured.";
        public static string unclassifiedBannerText = "UNCLASSIFIED";
        public static string cuiBannerText = "CUI";
        public static string confidentialBannerText = "CONFIDENTIAL";
        public static string secretBannerText = "SECRET";
        public static string topsecretBannerText = "TOP SECRET";
        public static string topsecretsciBannerText = "TOP SECRET//SCI";
        public static int[][] simpleBannerColors = new int[][] { unconfiguredBannerColor, unclassifiedBannerColor, cuiBannerColor, confidentialBannerColor, secretBannerColor, topsecretBannerColor, topsecretsciBannerColor };
        public static string[] simpleBannerTexts = { unconfiguredBannerText, unclassifiedBannerText, cuiBannerText, confidentialBannerText, secretBannerText, topsecretBannerText, topsecretsciBannerText };
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
            //for each screen that exists, build me a new banner on that screen with color and text values defined.
            BuildBanners();
            //set a timer for refreshing banners if needed
            RefreshBannerTimer();
        }
        public static void GetRegValues()
        {
            //64 bit view only on 64 bit Windows, 32 bit XP must use its default view
            RegistryView view = Environment.Is64BitOperatingSystem ? RegistryView.Registry64 : RegistryView.Default;
            try
            {
                ReadRegValues(view);
            }
            catch (System.Security.SecurityException) //access denied on the policy key, show unconfigured instead of crashing
            {
                bannerColor = simpleBannerColors[0];
                bannerText = simpleBannerTexts[0];
            }
        }
        private static void ReadRegValues(RegistryView view)
        {
            //grab registry key and see if it exists
            using (var hklm = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view))
            using (var checkKey = hklm.OpenSubKey(@"SOFTWARE\Policies\SystemBanner", RegistryKeyPermissionCheck.ReadSubTree))
            {
                if (checkKey != null)
                {
                    var key = hklm.OpenSubKey(@"SOFTWARE\Policies\SystemBanner", RegistryKeyPermissionCheck.ReadSubTree);
                    //start from a fresh array, writing into bannerColor would overwrite the stock color arrays it points to on a second read
                    bannerColor = (int[])unconfiguredBannerColor.Clone();
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
                        if (((int)simpleValue > 0) & ((int)simpleValue <= 6)) //check bounds of input fron registry against 
                        {
                            bannerColor = simpleBannerColors[(int)simpleValue];
                            bannerText = simpleBannerTexts[(int)simpleValue];
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

                }
                //if no reg values, set to not configured.
                else
                {
                    bannerColor = simpleBannerColors[0];
                    bannerText = simpleBannerTexts[0];
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
            //GetRegValues();
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
            if (oldBannerColor != bannerColor)
            {
                RebuildBanners();
                oldBannerColor = bannerColor;
            }
            if (oldBannerText != bannerText)
            {
                RebuildBanners();
                oldBannerText = bannerText;
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
