# SystemBanner

-----
ABOUT
-----

SystemBanner is an application used to display information security attributes or classification markings applicable for the Windows systems it runs on.

SystemBanner was built with standards in mind. For example, SystemBanner comes out of the box with Group Policy templates that can configure SystemBanner to display the different levels of United States Classified National Security Information as defined by EO 13526, as amended, and United States Controlled Unclassified Information as defined by EO 13556, as amended.

In addition, custom options implemented in Group Policy which sets relevant Registry values allow for other types of organizations to display custom messages and colors to warn users of Windows-based computers of the sensitivity of the information displayed, such as PII, PHI, Proprietary, or any kind of text-based marking or warning.

SystemBanner displays the selected message to the user as soon as they are logged into Windows via one or more graphical SystemBanner AppBars. As the user connects to new displays or resizes existing ones, SystemBanner regenerates new SystemBanner AppBars to accommodate those changes.

This fork brings SystemBanner to Windows XP SP3, Windows Vista SP2 and Windows 7 (one x86 executable, .NET Framework 4.0).

--------
FEATURES
--------

- **Windows XP SP3, Windows Vista SP2 and Windows 7 support.** Targets .NET Framework 4.0 and x86, the newest runtime XP supports. The same executable runs on 32 and 64 bit Windows Vista and Windows 7.
- **Banner on the logon screen.** The banner is also shown on the secure Winlogon desktop: the logon screen (classic logon dialog and Welcome screen), the locked workstation and the Ctrl+Alt+Del screen, including right after a logoff.
- **Persistence.** A Windows service restarts the banner within about 3 seconds if a user closes or kills it. Alt+F4 does not close the banner, and Windows restarts the service if it crashes.
- **Always visible.** The banner is fully opaque and always on top. The bottom banner sits right below the taskbar in the z-order, so the Start menu and tray notifications that open over it stay readable.
- **Fullscreen videos stay fully visible.** When an app goes fullscreen (tested with VLC and Firefox), the bottom banner moves to the very bottom of the screen and SystemBanner resizes the app once to fit between the top and bottom banners, over the taskbar. The banners never hide part of the video, and everything goes back in place when fullscreen ends.
- **Live configuration updates.** Classification, text, colors and banner position changes apply in about one second, on the user banner and on the logon screen banner, with no restart.
- **Troubleshooting.** Crash logs with full stack traces, and two scripts that turn debug logging on and off and gather every log in one folder.

![Alt text](Docs/Images/XP_Logon_Screenshot.png?raw=true)
![Alt text](Docs/Images/XP_Classic_Logon_Screenshot.png?raw=true)
![Alt text](Docs/Images/XP_Desktop_Screenshot.png?raw=true)
![Alt text](Docs/Images/XP_Fullscreen_Screenshot.png?raw=true)

Windows Vista logon screen, and UAC consent prompt (the banner is also shown on the secure desktop):

![Alt text](Docs/Images/Vista_Logon_Screenshot.png?raw=true)
![Alt text](Docs/Images/Vista_UAC_Screenshot.png?raw=true)

*Fullscreen screenshot: Big Buck Bunny, (c) copyright 2008, Blender Foundation, www.bigbuckbunny.org, licensed under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).*

-----------------
REPOSITORY LAYOUT
-----------------

| Folder | Content |
|---|---|
| `XP/` | Everything needed on a Windows XP computer: binaries, install and removal scripts, Group Policy template (ADM), debug scripts. |
| `Vista/` | Everything needed on a Windows Vista or Windows 7 computer: the same binaries, install and removal scripts, Group Policy templates (ADMX/ADML), debug scripts. |
| `Code/` | Source code (Visual Studio solution). |
| `Docs/` | Screenshots used in this README. |
| `Original/` | The original SystemBanner 1.1 files (Windows 10/11 MSI, scripts, ADMX templates), kept for reference. They do not include the features of this fork. |

------------
INSTALLATION
------------

### Windows Vista SP2 and Windows 7 (32 or 64 bit)

Requirements: Windows Vista SP2 or Windows 7, .NET Framework 4.0 (or a later 4.x version), an administrator account. Windows 7 uses the files of the `Vista` folder.

1. Copy the whole `Vista` folder to the computer.
2. Right click `Vista\InstallSystemBanner_Vista.bat` and select "Run as administrator".
3. The installer ends with `[OK] The SystemBanner service is running`. The service starts the banner within a few seconds. Lock the session with Win+L to see the logon screen banner.

It works like the Windows XP installer below, with these differences: it copies the ADMX/ADML templates to `C:\Windows\PolicyDefinitions`, it does not mark the service as interactive (useless since Vista isolates services in session 0), and it lets the service start the banner, so the banner runs with the user's normal rights and not as administrator.

### Windows XP SP3

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

-------
REMOVAL
-------

Run `XP\RemoveSystemBanner_XP.bat` as an administrator (on Vista, right click `Vista\RemoveSystemBanner_Vista.bat` > Run as administrator). It stops and deletes the service, kills all running instances, restarts Explorer to release the screen space reserved by the banners, and deletes the files, the Run key and the Group Policy templates.

--------------
ADMINISTRATION
--------------

SystemBanner reads its configuration from `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\SystemBanner`, set by Group Policy or directly in the registry:

| Value | Type | Meaning |
|---|---|---|
| `Simple` | DWORD | Stock classification: 0 unconfigured, 1 UNCLASSIFIED, 2 CUI, 3 CONFIDENTIAL, 4 SECRET, 5 TOP SECRET, 6 TOP SECRET//SCI. Overrides the custom settings. |
| `0`, `1`, `2` | DWORD | Custom background color, red, green, blue (0-255). |
| `3`, `4`, `5` | DWORD | Custom text color, red, green, blue (0-255). |
| `Text` | String | Custom text. |
| `TopAndBottom` | DWORD | 1 shows a banner at the top and at the bottom of each screen. |
| `Debug` | DWORD | 1 turns debug logging on. |

To use Group Policy on Windows Vista, open `gpedit.msc`: the installer already copied the ADMX/ADML templates, and the settings appear under Computer Configuration > Administrative Templates > SystemBanner.

To use Group Policy on Windows XP, open `gpedit.msc`, right click Computer Configuration > Administrative Templates > Add/Remove Templates > Add, and select `C:\WINDOWS\inf\SystemBanner.adm`. The settings appear under Computer Configuration > Administrative Templates > SystemBanner.

Every change applies within about one second.

Active Directory Administrators - copy `Vista\Group Policy\SystemBanner.admx` and its `en-US\SystemBanner.adml` to the PolicyDefinitions folder (or Central Store) of your domain, or add `XP\SystemBanner.adm` to a Group Policy Object, to configure SystemBanner across your Domain or Forest. Run `gpupdate /force` on a computer to apply a change right away.

------------
HOW IT WORKS
------------

SystemBanner runs one executable in three modes:

- `SystemBanner.exe`: the banner of a user session. It registers an AppBar on each screen so windows do not cover it, keeps itself on top, and fits fullscreen apps between the banners. It is started by the Run key at logon and by the service.
- `SystemBanner.exe /service`: the `SystemBanner` Windows service, running as LocalSystem. Every 3 seconds it checks that the logon screen banner runs, and that every active user session with Explorer running has its banner, and restarts whatever is missing.
- `SystemBanner.exe /winlogon`: the logon screen banner. The service starts it as LocalSystem directly on the `WinSta0\Winlogon` desktop. It is a plain opaque window, because Windows XP does not draw layered windows created on that desktop while it is hidden. It repaints itself when the Winlogon desktop comes on screen and survives logoffs.

On Windows XP the service shares session 0 with the console, so one logon screen banner is enough. On Windows Vista the service is isolated in session 0 and every session has its own Winlogon desktop, and the logon screen gets a new session after each logoff. The service therefore starts one logon screen banner per session, with a copy of its own LocalSystem token moved to that session.

All modes watch `HKLM\SOFTWARE\Policies` for changes and rebuild their banners when the configuration changes. A 5 second timer also checks the configuration and the display layout.

---------------
TROUBLESHOOTING
---------------

Use the scripts in `XP\Debug` or `Vista\Debug`, as an administrator (on Vista, right click > Run as administrator):

1. Run `EnableDebug_XP.bat` or `EnableDebug_Vista.bat`. It turns debug logging on and restarts the service.
2. Reproduce the problem, then press a key in the script window.
3. The script gathers every log in a `SystemBanner_logs` folder on the Desktop: crash and debug logs, service state, running SystemBanner processes, current settings and SystemBanner events (and the session list on Vista).
4. Run `DisableDebug_XP.bat` or `DisableDebug_Vista.bat` when you are done.

If the banner does not show the configured classification, run `"C:\Program Files\SystemBanner\SystemBanner.exe" /diag` from a normal (not elevated) command prompt. It writes `SystemBanner_diag.txt` on the Desktop: Windows and .NET versions, process bitness, account, the SystemBanner values seen in each registry view (or the exact error), and what SystemBanner ends up reading. The Vista debug script runs it too.

Log locations, if you need them by hand:

- **Event Viewer**, Application log, Source `Application`, Event ID 1902, when `Debug` is 1. The "description cannot be found" text in each event is expected, the useful information follows it.
- **Crash logs**, always on: `SystemBanner_crash.log` with the full stack trace, in `C:\Windows\Temp` for the service and the logon screen banners, and in the user's `%TEMP%` folder for the user banner.
- **Debug log fallback**: `SystemBanner_debug.log` in the same folders, used when a standard user cannot write to the event log.

-----------------
KNOWN LIMITATIONS
-----------------

- Apps in exclusive DirectX fullscreen mode (mostly games) cannot be resized or covered by any window, including SystemBanner.
- An app that forces itself back to full screen after being fitted is not resized again, to avoid a resize loop. The top banner then covers the top of it.
- While fitted, a fullscreen app is kept on top of the taskbar. If you switch to another window without leaving fullscreen, the app is put back to a normal window but keeps its fitted size.
- Windows XP: with Fast User Switching, the logon screen banner is only shown on the console session. Domain joined computers, where Fast User Switching is off, are not affected. Windows Vista gets one logon screen banner per session.
- Windows Vista: the banner runs with the user's normal rights, so it cannot resize a fullscreen app running as administrator. The top banner then covers the top of it.
- Windows Vista: the UAC consent prompt uses the same secure desktop as the logon screen, so the banner is shown on it too.
- An administrator can stop the service and remove SystemBanner. Standard users cannot.
- The XP scripts use `taskkill` and `eventquery.vbs`, which are not available on Windows XP Home.
- Tested on Windows XP SP3 (x86), Windows Vista SP2 (x86 and x64) and Windows 7 (x64), including three screens, a standard user account, Fast User Switching on Vista and removal. Windows 8 and later have not been tested.

--------
BUILDING
--------

The project in `Code/SystemBanner` targets .NET Framework 4.0, x86. It builds with Visual Studio 2019 and the .NET Framework 4.0 targeting pack. Visual Studio 2022 no longer ships that targeting pack: add the `Microsoft.NETFramework.ReferenceAssemblies.net40` NuGet package to build it. The binaries in `XP/Binaries` and `Vista/Binaries` are the same build: Release, x86, with symbols (`SystemBanner.pdb`).

-------
CREDITS
-------

SystemBanner was created by Aaron Wawrzyniak ([awawrzyniak10](https://github.com/awawrzyniak10/SystemBanner)). The Windows XP and Vista fork (XP and Vista ports, logon screen banner, watchdog service, live updates, fullscreen handling) is by Cole. Stock classification colors are based on the GSA form color information collected by Frank Caviggia (https://github.com/fcaviggia/classification-banner).

SystemBanner is released under the MIT License, see `LICENSE`.
