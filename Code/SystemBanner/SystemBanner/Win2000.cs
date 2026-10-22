//Copyright (c) 2026, Cole. MIT License Applies.
#if WIN2000
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Win32;

namespace SystemBanner
{
    //Windows 2000 build only (.NET Framework 2.0, compiled with WIN2000 defined).

    //.NET 2.0 has no registry views, Windows 2000 is 32 bit only: a single default view
    internal enum RegistryView
    {
        Default
    }

    internal static class Win2000
    {
        #region .NET 2.0 REPLACEMENTS

        [DllImport("ADVAPI32", CharSet = CharSet.Unicode)]
        private static extern int RegOpenKeyEx(IntPtr hKey, string lpSubKey, int ulOptions, int samDesired, out IntPtr phkResult);
        private static readonly IntPtr HKEY_LOCAL_MACHINE = new IntPtr(unchecked((int)0x80000002));
        private const int KEY_READ = 0x20019;

        //HKLM\SOFTWARE\Policies opened with the Win32 API, as .NET 2.0 RegistryKey has no Handle to watch, or IntPtr.Zero
        public static IntPtr OpenPoliciesKeyHandle()
        {
            IntPtr policies;
            return RegOpenKeyEx(HKEY_LOCAL_MACHINE, @"SOFTWARE\Policies", 0, KEY_READ, out policies) == 0 ? policies : IntPtr.Zero;
        }

        public static string Join(int[] values) //string.Join(",", int[]) is .NET 4.0
        {
            string[] parts = new string[values.Length];
            for (int i = 0; i < values.Length; i++)
            {
                parts[i] = values[i].ToString();
            }
            return string.Join(",", parts);
        }

        public static bool SameColors(int[] a, int[] b) //Enumerable.SequenceEqual is .NET 3.5
        {
            if (a.Length != b.Length)
            {
                return false;
            }
            for (int i = 0; i < a.Length; i++)
            {
                if (a[i] != b[i])
                {
                    return false;
                }
            }
            return true;
        }

        //for /diag, as Windows 2000 has neither tasklist.exe nor sc.exe
        public static string ProcessAndServiceReport()
        {
            System.Text.StringBuilder report = new System.Text.StringBuilder();
            report.AppendLine();
            try
            {
                using (System.ServiceProcess.ServiceController service = new System.ServiceProcess.ServiceController("SystemBanner"))
                {
                    report.AppendLine("Service SystemBanner: " + service.Status);
                }
            }
            catch (Exception ex)
            {
                report.AppendLine("Service SystemBanner: not installed (" + ex.Message + ")");
            }
            System.Diagnostics.Process current = System.Diagnostics.Process.GetCurrentProcess();
            foreach (System.Diagnostics.Process p in System.Diagnostics.Process.GetProcessesByName(current.ProcessName))
            {
                report.AppendLine("Process SystemBanner.exe, PID " + p.Id + ", session " + p.SessionId + (p.Id == current.Id ? " (this /diag)" : ""));
            }
            foreach (System.Diagnostics.Process p in System.Diagnostics.Process.GetProcessesByName("explorer"))
            {
                report.AppendLine("Process explorer.exe, PID " + p.Id + ", session " + p.SessionId);
            }
            return report.ToString();
        }

        #endregion

        #region SETUP

        //Windows 2000 ships without sc.exe, reg.exe and taskkill.exe, so SystemBanner installs and removes itself.
        //The result goes to %TEMP%\SystemBanner_setup.log, shown by the install and removal scripts.
        // /stop      stops the service and every other running SystemBanner (before copying a new version)
        // /install   Run key, SystemBanner service (automatic, LocalSystem, interactive, restarted after a crash), starts it
        // /uninstall stops and deletes the service, removes the Run key, restarts Explorer to free the AppBar space
        public static int Setup(string command)
        {
            System.Text.StringBuilder log = new System.Text.StringBuilder();
            int result = 0;
            try
            {
                if (command == "/stop")
                {
                    Stop(log);
                }
                else if (command == "/install")
                {
                    Install(log);
                }
                else if (command == "/uninstall")
                {
                    Uninstall(log);
                }
            }
            catch (Exception ex)
            {
                log.AppendLine("[ERROR] " + ex.Message);
                result = 1;
            }
            try
            {
                System.IO.File.WriteAllText(System.IO.Path.Combine(System.IO.Path.GetTempPath(), "SystemBanner_setup.log"), log.ToString());
            }
            catch (Exception)
            {
                //the exit code still tells the script
            }
            return result;
        }

        [DllImport("ADVAPI32", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr OpenSCManager(string lpMachineName, string lpDatabaseName, uint dwDesiredAccess);
        [DllImport("ADVAPI32", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr OpenService(IntPtr hSCManager, string lpServiceName, uint dwDesiredAccess);
        [DllImport("ADVAPI32", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CreateService(IntPtr hSCManager, string lpServiceName, string lpDisplayName, uint dwDesiredAccess, uint dwServiceType, uint dwStartType, uint dwErrorControl, string lpBinaryPathName, string lpLoadOrderGroup, IntPtr lpdwTagId, string lpDependencies, string lpServiceStartName, string lpPassword);
        [DllImport("ADVAPI32", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool ChangeServiceConfig(IntPtr hService, uint dwServiceType, uint dwStartType, uint dwErrorControl, string lpBinaryPathName, string lpLoadOrderGroup, IntPtr lpdwTagId, string lpDependencies, string lpServiceStartName, string lpPassword, string lpDisplayName);
        [DllImport("ADVAPI32", EntryPoint = "ChangeServiceConfig2W", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool ChangeServiceDescription(IntPtr hService, int dwInfoLevel, ref SERVICE_DESCRIPTION lpInfo);
        [DllImport("ADVAPI32", EntryPoint = "ChangeServiceConfig2W", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool ChangeServiceFailureActions(IntPtr hService, int dwInfoLevel, ref SERVICE_FAILURE_ACTIONS lpInfo);
        [DllImport("ADVAPI32", SetLastError = true)]
        private static extern bool DeleteService(IntPtr hService);
        [DllImport("ADVAPI32")]
        private static extern bool CloseServiceHandle(IntPtr hSCObject);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct SERVICE_DESCRIPTION
        {
            public string lpDescription;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct SERVICE_FAILURE_ACTIONS
        {
            public int dwResetPeriod;
            public string lpRebootMsg;
            public string lpCommand;
            public int cActions;
            public IntPtr lpsaActions; //SC_ACTION array: {int Type, int Delay}
        }

        private const uint SC_MANAGER_ALL_ACCESS = 0xF003F;
        private const uint SERVICE_ALL_ACCESS = 0xF01FF;
        private const uint SERVICE_INTERACTIVE_OWN_PROCESS = 0x00000010 | 0x00000100; // SERVICE_WIN32_OWN_PROCESS | SERVICE_INTERACTIVE_PROCESS
        private const uint SERVICE_AUTO_START = 2;
        private const uint SERVICE_ERROR_NORMAL = 1;
        private const int SERVICE_CONFIG_DESCRIPTION = 1;
        private const int SERVICE_CONFIG_FAILURE_ACTIONS = 2;
        private const int SC_ACTION_RESTART = 1;
        private const string ServiceName = "SystemBanner";
        private const string RunKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";

        private static void Stop(System.Text.StringBuilder log)
        {
            using (System.ServiceProcess.ServiceController service = new System.ServiceProcess.ServiceController(ServiceName))
            {
                try
                {
                    if (service.Status != System.ServiceProcess.ServiceControllerStatus.Stopped)
                    {
                        service.Stop();
                        service.WaitForStatus(System.ServiceProcess.ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(20));
                    }
                    log.AppendLine("Service stopped.");
                }
                catch (InvalidOperationException)
                {
                    log.AppendLine("Service not installed.");
                }
            }
            //the user banner and the logon screen banner (the service no longer restarts them)
            System.Diagnostics.Process current = System.Diagnostics.Process.GetCurrentProcess();
            foreach (System.Diagnostics.Process p in System.Diagnostics.Process.GetProcessesByName(current.ProcessName))
            {
                if (p.Id != current.Id)
                {
                    p.Kill();
                    p.WaitForExit(5000);
                    log.AppendLine("SystemBanner process " + p.Id + " stopped.");
                }
            }
        }

        private static void Install(System.Text.StringBuilder log)
        {
            string exe = Application.ExecutablePath;
            using (RegistryKey run = Registry.LocalMachine.CreateSubKey(RunKey))
            {
                run.SetValue("SystemBanner", "\"" + exe + "\"");
            }
            log.AppendLine("Run key added: the banner starts at every user logon.");

            IntPtr scm = OpenSCManager(null, null, SC_MANAGER_ALL_ACCESS);
            if (scm == IntPtr.Zero)
            {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "Cannot open the service manager");
            }
            try
            {
                string binPath = "\"" + exe + "\" /service";
                IntPtr service = OpenService(scm, ServiceName, SERVICE_ALL_ACCESS);
                if (service == IntPtr.Zero)
                {
                    service = CreateService(scm, ServiceName, ServiceName, SERVICE_ALL_ACCESS, SERVICE_INTERACTIVE_OWN_PROCESS, SERVICE_AUTO_START, SERVICE_ERROR_NORMAL, binPath, null, IntPtr.Zero, null, null, null); //null account = LocalSystem
                    if (service == IntPtr.Zero)
                    {
                        throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "Cannot create the SystemBanner service");
                    }
                    log.AppendLine("Service created.");
                }
                else
                {
                    if (!ChangeServiceConfig(service, SERVICE_INTERACTIVE_OWN_PROCESS, SERVICE_AUTO_START, SERVICE_ERROR_NORMAL, binPath, null, IntPtr.Zero, null, null, null, ServiceName))
                    {
                        throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "Cannot update the SystemBanner service");
                    }
                    log.AppendLine("Service updated.");
                }
                try
                {
                    SERVICE_DESCRIPTION description = new SERVICE_DESCRIPTION();
                    description.lpDescription = "Displays SystemBanner on the logon screen and keeps the user banner running.";
                    ChangeServiceDescription(service, SERVICE_CONFIG_DESCRIPTION, ref description);
                    //restart 5 sec after each crash
                    IntPtr actions = Marshal.AllocHGlobal(3 * 8);
                    try
                    {
                        for (int i = 0; i < 3; i++)
                        {
                            Marshal.WriteInt32(actions, i * 8, SC_ACTION_RESTART);
                            Marshal.WriteInt32(actions, i * 8 + 4, 5000);
                        }
                        SERVICE_FAILURE_ACTIONS failure = new SERVICE_FAILURE_ACTIONS();
                        failure.cActions = 3;
                        failure.lpsaActions = actions;
                        if (ChangeServiceFailureActions(service, SERVICE_CONFIG_FAILURE_ACTIONS, ref failure))
                        {
                            log.AppendLine("Service set to restart 5 seconds after a crash.");
                        }
                        else
                        {
                            log.AppendLine("[WARNING] Cannot set the restart after a crash, error " + Marshal.GetLastWin32Error() + ".");
                        }
                    }
                    finally
                    {
                        Marshal.FreeHGlobal(actions);
                    }
                }
                finally
                {
                    CloseServiceHandle(service);
                }
            }
            finally
            {
                CloseServiceHandle(scm);
            }

            using (System.ServiceProcess.ServiceController service = new System.ServiceProcess.ServiceController(ServiceName))
            {
                if (service.Status != System.ServiceProcess.ServiceControllerStatus.Running)
                {
                    service.Start();
                    service.WaitForStatus(System.ServiceProcess.ServiceControllerStatus.Running, TimeSpan.FromSeconds(20));
                }
            }
            log.AppendLine("[OK] The SystemBanner service is running and starts the banner. Lock the computer with Ctrl+Alt+Del > Lock Computer to see the logon screen banner.");
        }

        private static void Uninstall(System.Text.StringBuilder log)
        {
            Stop(log);
            IntPtr scm = OpenSCManager(null, null, SC_MANAGER_ALL_ACCESS);
            if (scm != IntPtr.Zero)
            {
                IntPtr service = OpenService(scm, ServiceName, SERVICE_ALL_ACCESS);
                if (service != IntPtr.Zero)
                {
                    log.AppendLine(DeleteService(service) ? "Service deleted." : "[ERROR] Cannot delete the service, error " + Marshal.GetLastWin32Error() + ".");
                    CloseServiceHandle(service);
                }
                CloseServiceHandle(scm);
            }
            using (RegistryKey run = Registry.LocalMachine.OpenSubKey(RunKey, true))
            {
                if (run != null)
                {
                    run.DeleteValue("SystemBanner", false);
                }
            }
            log.AppendLine("Run key removed.");
            //the killed banners could not release their AppBar space, a new Explorer does
            foreach (System.Diagnostics.Process explorer in System.Diagnostics.Process.GetProcessesByName("explorer"))
            {
                explorer.Kill();
                explorer.WaitForExit(5000);
            }
            System.Diagnostics.Process.Start("explorer.exe");
            log.AppendLine("Explorer restarted.");
            log.AppendLine("[OK] SystemBanner removed.");
        }

        #endregion
    }
}
#endif
