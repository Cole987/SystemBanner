# SystemBanner

-----
ABOUT
-----

SystemBanner is an application used to display information security attributes or classification markings applicable for the Windows systems it runs on.

SystemBanner was built with standards in mind. For example, SystemBanner comes out of the box with Group Policy templates that can configure SystemBanner to display the different levels of United States Classified National Security Information as defined by EO 13526, as amended, and United States Controlled Unclassified Information as defined by EO 13556, as amended.

![Alt text](Docs/Images/SystemBanner_Working_Screenshot.png?raw=true)

In addition, custom options implemented in Group Policy which sets relevant Registry values allow for other types of organizations to display custom messages and colors to warn users of Windows-based computers of the sensitivity of the information displayed, such as PII, PHI, Proprietary, or any kind of text-based marking or warning.

![Alt text](Docs/Images/SystemBanner_GPO_Screenshot.png?raw=true)
![Alt text](Docs/Images/SystemBanner_Custom_Screenshot.png?raw=true)

SystemBanner displays the selected message to the user as soon as they are logged into Windows via one or more graphical SystemBanner AppBars. As the user connects to new displays or resizes existing ones, SystemBanner regenerates new SystemBanner AppBars to accommodate those changes.

This repository contains two editions:

| Edition | Folder | Runtime | Tested on |
|---|---|---|---|
| **Windows XP edition** (this fork) | `XP/` | .NET Framework 4.0, x86 | Windows XP SP3 (x86) |
| Original edition 1.1 | repository root, `SystemBannerSetup.msi` | .NET Framework 4.7.2 | Windows 10/11, Windows Server 2016/2019/2022/2025 (x86_64 and arm64) |

The source code in `Code/` is the Windows XP edition. The MSI, `InstallSystemBanner.bat` and the binaries in `Code/SystemBanner/SystemBanner/bin/Release` are still the original 1.1 build and do not include the changes below.

---------------------------------
WHAT'S NEW IN THE WINDOWS XP EDITION
---------------------------------

- **Windows XP SP3 support.** Retargeted to .NET Framework 4.0 and x86, the newest runtime and the architecture XP supports.
- **Banner on the logon screen.** The banner is also shown on the secure Winlogon desktop: the logon screen (classic logon dialog and Welcome screen), the locked workstation and the Ctrl+Alt+Del screen, including right after a logoff.
- **Persistence.** A Windows service restarts the banner within about 3 seconds if a user closes or kills it. Alt+F4 does not close the banner, and Windows restarts the service if it crashes.
- **Always visible.** The banner is fully opaque and always on top. The transparency and the fading on mouse over and over fullscreen apps were removed. The bottom banner sits right below the taskbar in the z-order, so the Start menu and tray notifications that open over it stay readable.
- **Fullscreen videos stay fully visible.** When an app goes fullscreen (tested with VLC and Firefox), SystemBanner resizes it once to fit between the top and bottom banners, so the banner never hides part of the video.
- **Live configuration updates.** Classification, text, colors and banner position changes apply in about one second, on the user banner and on the logon screen banner, with no restart.
- **Troubleshooting.** Crash logs with full stack traces, and two scripts that turn debug logging on and off and gather every log in one folder.

---------------------------------
INSTALLATION (WINDOWS XP EDITION)
---------------------------------

Requirements: Windows XP Professional SP3 (x86), .NET Framework 4.0, an administrator account.

1. Copy the whole `XP` folder to the computer.
2. Run `XP\InstallSystemBanner_XP.bat` as an administrator.
3. The installer ends with `[OK] The SystemBanner service is running`. Lock the session with Win+L to see the logon screen banner.

The installer:

- checks for administrator rights and .NET Framework 4.0;
- copies `SystemBanner.exe`, `SystemBanner.exe.config` and `SystemBanner.pdb` to `C:\Program Files\SystemBanner`;
- copies the `SystemBanner.adm` Group Policy template to `C:\WINDOWS\inf`;
- precompiles SystemBanner with `ngen` for a faster start;
- adds a `HKLM\...\Run` key so the banner starts at every user logon;
- installs and starts the `SystemBanner` service (automatic start, LocalSystem, restarts itself 5 seconds after a crash).

To remove SystemBanner, run `XP\RemoveSystemBanner_XP.bat` as an administrator. It stops and deletes the service, kills all running instances, restarts Explorer to release the screen space reserved by the banners, and deletes the files, the Run key and the ADM template.

----------------------------------
INSTALLATION (ORIGINAL EDITION 1.1)
----------------------------------

To install SystemBanner, either install SystemBannerSetup.msi (double click, msiexec via CLI, etc.) or download the project ZIP and run InstallSystemBanner.bat as an administrator. 

![Alt text](Docs/Images/SystemBanner_Install_Screenshot.png?raw=true)

Each installer copies the SystemBanner Binary (SystemBanner.exe) to "C:\Program Files\SystemBanner", copies ADMX and ADML files (for Group Policy Functionality) to C:\Windows\PolicyDefinitions\ and C:\Windows\PolicyDefinitions\en-US\, creates a startup app registry key for SystemBanner to run on logon of any user, and puts a Registry value into "HKLM\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" to allow SystemBanner to be High DPI aware (ignore Windows Scaling). When installing with the MSI, SystemBanner will start the next time the user logs in or the next time the user runs C:\Program Files\SystemBanner\SystemBanner.exe, whichever happens first. 

To remove SystemBanner, either remove SystemBannerSetup.msi or run RemoveSystemBanner.bat as an administrator. Each removal method kills all running instances of SystemBanner.exe, then deletes "C:\Program Files\SystemBanner\SystemBanner.exe", the "C:\Program Files\SystemBanner" folder, all SystemBanner ADMX and ADML files from C:\Windows\PolicyDefinitions\ and C:\Windows\PolicyDefinitions\en-US\, and removes itself as a startup app and HIGHDPIAWARE app in registry. Restarting Explorer.exe may clean up any remaining AppBar API calls that have not been cleaned up (the space the Banner makes for itself in the Windows UI).

--------------
ADMINISTRATION
--------------

Both editions read their configuration from `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\SystemBanner`, set by Group Policy or directly in the registry:

| Value | Type | Meaning |
|---|---|---|
| `Simple` | DWORD | Stock classification: 0 unconfigured, 1 UNCLASSIFIED, 2 CUI, 3 CONFIDENTIAL, 4 SECRET, 5 TOP SECRET, 6 TOP SECRET//SCI. Overrides the custom settings. |
| `0`, `1`, `2` | DWORD | Custom background color, red, green, blue (0-255). |
| `3`, `4`, `5` | DWORD | Custom text color, red, green, blue (0-255). |
| `Text` | String | Custom text. |
| `TopAndBottom` | DWORD | 1 shows a banner at the top and at the bottom of each screen. |
| `Debug` | DWORD | 1 turns debug logging on. |

**Windows XP:** use `SystemBanner.adm`. In `gpedit.msc`, right click Computer Configuration > Administrative Templates > Add/Remove Templates > Add, and select `C:\WINDOWS\inf\SystemBanner.adm`. The settings appear under Computer Configuration > Administrative Templates > SystemBanner. Every change applies within about one second. For a domain policy, run `gpupdate /force` to apply it right away.

**Windows 10/11 and Windows Server:** use the ADMX/ADML files in `Group Policy/`. The ADMX/ADML files can be used to locally manage policy or they can be loaded onto a domain controller for domain-wide management. In either scenario, configuration items are located in Computer Configuration > Administrative Templates > SystemBanner. With the original edition 1.1, most changes are picked up automatically while running, but custom color changes require an application restart.

Active Directory Administrators - please manually copy the ADMX/ADML files (or the ADM file for Windows XP) to their appropriate locations on your domain controller to allow for Group Policy configuration of SystemBanner across your Domain or Forest.

Intune Administrators - ADMX/ADML importing appears to be on the roadmap (https://learn.microsoft.com/en-us/intune/device-configuration/settings-catalog/import-custom-admx-templates). Until then, please use Local GPO to test/build your desired configuration, then deploy the corresponding registry values (HKEY_LOCAL_MACHINE\SOFTWARE\Policies\SystemBanner) to your fleet.

------------
HOW IT WORKS
------------

The Windows XP edition runs one executable in three modes:

- `SystemBanner.exe`: the banner of a user session. It registers an AppBar on each screen so windows do not cover it, keeps itself on top, and fits fullscreen apps between the banners. It is started by the Run key at logon and by the service.
- `SystemBanner.exe /service`: the `SystemBanner` Windows service, running as LocalSystem. Every 3 seconds it checks that the logon screen banner runs, and that every active user session with Explorer running has its banner, and restarts whatever is missing.
- `SystemBanner.exe /winlogon`: the logon screen banner. The service starts it as LocalSystem directly on the `WinSta0\Winlogon` desktop. It is a plain opaque window, because Windows XP does not draw layered windows created on that desktop while it is hidden. It repaints itself when the Winlogon desktop comes on screen and survives logoffs.

All modes watch `HKLM\SOFTWARE\Policies` for changes and rebuild their banners when the configuration changes. A 5 second timer also checks the configuration and the display layout.

---------------
TROUBLESHOOTING
---------------

On Windows XP, use the scripts in `XP\Debug`, as an administrator:

1. Run `EnableDebug_XP.bat`. It turns debug logging on and restarts the service.
2. Reproduce the problem, then press a key in the script window.
3. The script gathers every log in a `SystemBanner_logs` folder on the Desktop: crash and debug logs, service state, running SystemBanner processes, current settings and SystemBanner events.
4. Run `DisableDebug_XP.bat` when you are done.

Log locations, if you need them by hand:

- **Event Viewer**, Application log, Source `Application`, Event ID 1902, when `Debug` is 1. The "description cannot be found" text in each event is expected, the useful information follows it.
- **Crash logs**, always on: `SystemBanner_crash.log` with the full stack trace, in `C:\WINDOWS\Temp` for the service and the logon screen banner, and in the user's `%TEMP%` folder for the user banner.
- **Debug log fallback**: `SystemBanner_debug.log` in the same folders, used when a standard user cannot write to the event log.

-----------------
KNOWN LIMITATIONS
-----------------

- Apps in exclusive DirectX fullscreen mode (mostly games) cannot be resized or covered by any window, including SystemBanner.
- An app that forces itself back to full screen after being fitted is not resized again, to avoid a resize loop. The top banner then covers the top of it.
- With Fast User Switching, the logon screen banner is only shown on the console session. Domain joined computers, where Fast User Switching is off, are not affected.
- An administrator can stop the service and remove SystemBanner. Standard users cannot.
- The scripts use `taskkill` and `eventquery.vbs`, which are not available on Windows XP Home.
- The Windows XP edition has not been tested on Windows 10/11. The logon screen banner cannot work there, because services are isolated in session 0 since Windows Vista. Use the original edition 1.1 on those systems.

--------
BUILDING
--------

The project in `Code/SystemBanner` targets .NET Framework 4.0, x86. It builds with Visual Studio 2019 and the .NET Framework 4.0 targeting pack. Visual Studio 2022 no longer ships that targeting pack: add the `Microsoft.NETFramework.ReferenceAssemblies.net40` NuGet package to build it. The Windows XP edition binaries in `XP/Binaries` are built in Release, x86, with symbols (`SystemBanner.pdb`).

-------
CREDITS
-------

SystemBanner was created by Aaron Wawrzyniak ([awawrzyniak10](https://github.com/awawrzyniak10/SystemBanner)). The Windows XP edition (XP port, logon screen banner, watchdog service, live updates, fullscreen handling) is by Cole. Stock classification colors are based on the GSA form color information collected by Frank Caviggia (https://github.com/fcaviggia/classification-banner).

SystemBanner is released under the MIT License, see `LICENSE`.
