# SystemBanner

-----
ABOUT
-----

SystemBanner is an application used to display information security attributes or classification markings applicable for the Windows systems it runs on.

SystemBanner was built with standards in mind. For example, SystemBanner comes out of the box with Group Policy templates that can configure SystemBanner to display the different levels of United States Classified National Security Information as defined by EO 13526, as amended, and United States Controlled Unclassified Information as defined by EO 13556, as amended.

In addition, custom options implemented in Group Policy which sets relevant Registry values allow for other types of organizations to display custom messages and colors to warn users of Windows-based computers of the sensitivity of the information displayed, such as PII, PHI, Proprietary, or any kind of text-based marking or warning.

SystemBanner displays the selected message to the user as soon as they are logged into Windows via one or more graphical SystemBanner AppBars. As the user connects to new displays or resizes existing ones, SystemBanner regenerates new SystemBanner AppBars to accommodate those changes.

This fork brings SystemBanner to Windows XP SP3, Windows Vista SP2 and Windows 7 (one x86 executable, .NET Framework 4.0), and to Windows 2000 Professional SP4 (a separate .NET Framework 2.0 executable built from the same source). A native port runs on Mac OS X 10.6 Snow Leopard and later, in Objective-C up to OS X 10.11 El Capitan and in Swift from macOS 10.12 Sierra, see [MAC OS X AND MACOS](#mac-os-x-and-macos).

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

Windows Vista on three screens, with a top and a bottom banner on each screen:

![Alt text](Docs/Images/Vista_TripleScreen_Screenshot.png?raw=true)

Windows 7 locked computer:

![Alt text](Docs/Images/Win7_Logon_Screenshot.png?raw=true)

Windows 2000 startup, before the logon dialog (the banner is already shown on the secure desktop):

![Alt text](Docs/Images/Win2000_Logon_Screenshot.png?raw=true)

*Fullscreen screenshot: Big Buck Bunny, (c) copyright 2008, Blender Foundation, www.bigbuckbunny.org, licensed under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).*

-----------------
REPOSITORY LAYOUT
-----------------

| Folder | Content |
|---|---|
| `2000/` | Everything needed on a Windows 2000 computer: the .NET 2.0 binaries, install and removal scripts, Group Policy template (ADM), debug scripts. |
| `XP/` | Everything needed on a Windows XP computer: binaries, install and removal scripts, Group Policy template (ADM), debug scripts. |
| `Vista-7/` | Everything needed on a Windows Vista or Windows 7 computer: the same binaries, install and removal scripts, Group Policy templates (ADMX/ADML), debug scripts. |
| `SnowLeopard-ElCapitan/` | Everything needed on a Mac with Mac OS X 10.6 to OS X 10.11 (Intel): the app, the System Preferences pane, install and removal scripts, launchd agents, sample configuration profile. |
| `macOS/` | The same for macOS 10.12 Sierra and later, universal apps (Intel and Apple Silicon). |
| `macOS-ARM/` | The same for macOS 11 Big Sur and later on Apple Silicon only, without any Intel code. |
| `Code/` | Source code (Visual Studio solution, `Code/SystemBanner-SnowLeopard-ElCapitan` and `Code/SystemBanner-macOS` for the Mac). |
| `Docs/` | Screenshots used in this README. |
| `Original/` | The original SystemBanner 1.1 files (Windows 10/11 MSI, scripts, ADMX templates), kept for reference. They do not include the features of this fork. |

------------
INSTALLATION
------------

### Windows Vista SP2 and Windows 7 (32 or 64 bit)

Requirements: Windows Vista SP2 or Windows 7, .NET Framework 4.0 (or a later 4.x version), an administrator account. Windows 7 uses the files of the `Vista-7` folder.

1. Copy the whole `Vista-7` folder to the computer.
2. Right click `Vista-7\InstallSystemBanner_Vista-7.bat` and select "Run as administrator".
3. The installer ends with `[OK] The SystemBanner service is running`. The service starts the banner within a few seconds. Lock the session with Win+L to see the logon screen banner.

It works like the Windows XP installer below, with these differences: it copies the ADMX/ADML templates to `C:\Windows\PolicyDefinitions`, it does not mark the service as interactive (useless since Vista isolates services in session 0), and it lets the service start the banner, so the banner runs with the user's normal rights and not as administrator.

### Windows 2000 Professional SP4

Requirements: Windows 2000 Professional SP4, .NET Framework 2.0, an administrator account.

1. Copy the whole `2000` folder to the computer.
2. Run `2000\InstallSystemBanner_2000.bat` as an administrator.
3. The installer ends with `[OK] The SystemBanner service is running`. Lock the computer with Ctrl+Alt+Del > Lock Computer to see the logon screen banner.

Windows 2000 ships without `sc.exe`, `reg.exe` and `taskkill.exe`, so `SystemBanner.exe` does that work itself: `/stop` stops the service and the running banners, `/install` adds the Run key and installs and starts the service, `/uninstall` removes them. They report to `%TEMP%\SystemBanner_setup.log`, which the scripts display. The rest works like on Windows XP: same logon screen banner, same ADM template.

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

Run `XP\RemoveSystemBanner_XP.bat` or `2000\RemoveSystemBanner_2000.bat` as an administrator (on Vista and 7, right click `Vista-7\RemoveSystemBanner_Vista-7.bat` > Run as administrator). It stops and deletes the service, kills all running instances, restarts Explorer to release the screen space reserved by the banners, and deletes the files, the Run key and the Group Policy templates.

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

To use Group Policy on Windows Vista and 7, open `gpedit.msc`: the installer already copied the ADMX/ADML templates, and the settings appear under Computer Configuration > Administrative Templates > SystemBanner.

To use Group Policy on Windows 2000 and XP, open `gpedit.msc`, right click Computer Configuration > Administrative Templates > Add/Remove Templates > Add, and select `C:\WINDOWS\inf\SystemBanner.adm`. The settings appear under Computer Configuration > Administrative Templates > SystemBanner.

Every change applies within about one second.

Active Directory Administrators - copy `Vista-7\Group Policy\SystemBanner.admx` and its `en-US\SystemBanner.adml` to the PolicyDefinitions folder (or Central Store) of your domain, or add `XP\SystemBanner.adm` to a Group Policy Object, to configure SystemBanner across your Domain or Forest. Run `gpupdate /force` on a computer to apply a change right away.

------------
HOW IT WORKS
------------

SystemBanner runs one executable in three modes:

- `SystemBanner.exe`: the banner of a user session. It registers an AppBar on each screen so windows do not cover it, keeps itself on top, and fits fullscreen apps between the banners. It is started by the Run key at logon and by the service.
- `SystemBanner.exe /service`: the `SystemBanner` Windows service, running as LocalSystem. Every 3 seconds it checks that the logon screen banner runs, and that every active user session with Explorer running has its banner, and restarts whatever is missing.
- `SystemBanner.exe /winlogon`: the logon screen banner. The service starts it as LocalSystem directly on the `WinSta0\Winlogon` desktop. It is a plain opaque window, because Windows XP does not draw layered windows created on that desktop while it is hidden. It repaints itself when the Winlogon desktop comes on screen and survives logoffs.

On Windows XP the service shares session 0 with the console, so one logon screen banner is enough. On Windows Vista and 7 the service is isolated in session 0 and every session has its own Winlogon desktop, and the logon screen gets a new session after each logoff. The service therefore starts one logon screen banner per session, with a copy of its own LocalSystem token moved to that session.

All modes watch `HKLM\SOFTWARE\Policies` for changes and rebuild their banners when the configuration changes. A 5 second timer also checks the configuration and the display layout.

---------------
TROUBLESHOOTING
---------------

Use the scripts in `2000\Debug`, `XP\Debug` or `Vista-7\Debug`, as an administrator (on Vista and 7, right click > Run as administrator):

1. Run `EnableDebug_2000.bat`, `EnableDebug_XP.bat` or `EnableDebug_Vista-7.bat`. It turns debug logging on and restarts the service.
2. Reproduce the problem, then press a key in the script window.
3. The script gathers every log in a `SystemBanner_logs` folder on the Desktop: crash and debug logs, service state, running SystemBanner processes, current settings and SystemBanner events (and the session list on Vista and 7).
4. Run `DisableDebug_2000.bat`, `DisableDebug_XP.bat` or `DisableDebug_Vista-7.bat` when you are done.

If the banner does not show the configured classification, run `"C:\Program Files\SystemBanner\SystemBanner.exe" /diag` from a normal (not elevated) command prompt. It writes `SystemBanner_diag.txt` on the Desktop: Windows and .NET versions, process bitness, account, the SystemBanner values seen in each registry view (or the exact error), and what SystemBanner ends up reading. The Vista-7 debug script runs it too.

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
- Windows XP: with Fast User Switching, the logon screen banner is only shown on the console session. Domain joined computers, where Fast User Switching is off, are not affected. Windows Vista and 7 get one logon screen banner per session.
- Windows Vista and 7: the banner runs with the user's normal rights, so it cannot resize a fullscreen app running as administrator. The top banner then covers the top of it.
- Windows Vista and 7: the UAC consent prompt uses the same secure desktop as the logon screen, so the banner is shown on it too.
- An administrator can stop the service and remove SystemBanner. Standard users cannot.
- The XP scripts use `taskkill` and `eventquery.vbs`, which are not available on Windows XP Home.
- Windows 2000: there is no Win+L, lock the computer with Ctrl+Alt+Del > Lock Computer. The Windows 2000 debug script gathers the event log entries through `/diag` and Event Viewer only, as Windows 2000 has no command line event log tool.
- Tested on Windows 2000 Professional SP4, Windows XP SP3 (x86), Windows Vista SP2 (x86 and x64) and Windows 7 (x86 and x64), with the full test series on each of them: installation, logon screen, lock, logoff, UAC prompt on Vista and 7, live classification changes, restart after a kill, fullscreen and removal. Three screens, a standard user account and Fast User Switching were tested on Windows Vista. Windows 8 and later have not been tested.

-----------------
MAC OS X AND MACOS
-----------------

Tested on real Macs and virtual machines. On each of them: desktop banners, login window banner, live classification changes, and the settings (System Preferences pane or SystemBanner Settings) with an administrator account (Apply and password prompt) and with a standard account.

| macOS | Folder | Mac |
|---|---|---|
| Mac OS X 10.6.8 Snow Leopard | `SnowLeopard-ElCapitan` | Mac mini 2007 |
| OS X 10.9.5 Mavericks | `SnowLeopard-ElCapitan` | iMac 2011 |
| OS X 10.11.6 El Capitan | `SnowLeopard-ElCapitan` | Virtual machine |
| macOS 10.12 Sierra | `macOS` (with its embedded Swift runtime) | Virtual machine |
| macOS 26 | `macOS-ARM` | MacBook Pro M4 Pro |

macOS on Apple Silicon, top and bottom banners on the desktop:

![Alt text](Docs/Images/MacOS_ARM_Desktop.png?raw=true)

Login window:

![Alt text](Docs/Images/MacOS_ARM_Login.png?raw=true)

SystemBanner Settings opened by a standard user:

![Alt text](Docs/Images/MacOS_ARM_NonAdmin.png?raw=true)

Mac OS X 10.6 Snow Leopard, top and bottom banners and the SystemBanner pane in System Preferences:

![Alt text](Docs/Images/SNBanner_Desktop_ControlPanel.png?raw=true)

Mac OS X 10.6 Snow Leopard login window:

![Alt text](Docs/Images/SNBanner_LoginScreen.png?raw=true)

OS X 10.11 El Capitan, with the SystemBanner pane unlocked:

![Alt text](Docs/Images/ElCapitan-Finder.png?raw=true)

macOS 10.12 Sierra, desktop and login window:

![Alt text](Docs/Images/Sierra_Desktop.png?raw=true)
![Alt text](Docs/Images/Sierra_Login.png?raw=true)

The Mac versions are native apps, since nothing of the Windows code (AppBars, services, Winlogon, registry) exists on a Mac. They come in three folders, pick the one that matches the Mac:

| Folder | Mac | Language | Processor |
|---|---|---|---|
| `SnowLeopard-ElCapitan/` | Mac OS X 10.6 Snow Leopard to OS X 10.11 El Capitan | Objective-C | Intel 64 bit |
| `macOS/` | macOS 10.12 Sierra and later | Swift | Universal, Intel and Apple Silicon |
| `macOS-ARM/` | macOS 11 Big Sur and later | Swift, same source as `macOS/` | Apple Silicon only |

`macOS-ARM` is built from the same Swift source as `macOS`, without the Intel code and without the Swift runtime that `macOS` carries for 10.12 to 10.14.3 (180 KB instead of 11 MB per app). It is the version to keep once Apple drops Intel Macs. 32 bit Intel Macs (2006 Core Duo models) are not supported, today's Xcode cannot build for them any more.

Each folder holds the banner, `SystemBanner.app`, and a way to change the classification, the text, the colors and the top and bottom option, with a live preview, for administrators only:

- `SnowLeopard-ElCapitan`: a **SystemBanner pane in System Preferences** (in the Other section). Nothing can be changed until an administrator clicks the lock and types their password.
- `macOS` and `macOS-ARM`: the **SystemBanner Settings** app in Applications > Utilities, since recent macOS versions sideline third party panes in System Settings. It only opens for members of the admin group, and every change asks for an administrator password.

When a configuration profile manages SystemBanner, both show it and change nothing.

### Installation

Requirements: an administrator account, and the Mac listed for the folder.

1. Copy the whole folder (`SnowLeopard-ElCapitan`, `macOS` or `macOS-ARM`) to the Mac.
2. In Terminal, run its installer from that folder, for example `sudo ./InstallSystemBanner_macOS.sh`. It refuses to run on a Mac the folder is not meant for, and names the right folder.
3. The installer ends with `[OK] The SystemBanner banner is running`. Log out to see the login window banner.

All three installers put the files in the same places, so moving a Mac from one folder to another (after a macOS upgrade, for example) only takes running the other installer:

- `SystemBanner.app` in `/Library/Application Support/SystemBanner`;
- the SystemBanner pane in `/Library/PreferencePanes` (`SnowLeopard-ElCapitan`), or `SystemBanner Settings.app` in `/Applications/Utilities` (`macOS`, `macOS-ARM`);
- two launchd agents in `/Library/LaunchAgents`: `com.systembanner.agent` starts the banner in every user session, `com.systembanner.loginwindow` starts it on the login window. launchd restarts a banner within about 3 seconds if it is quit or killed.

To remove it, run the folder's removal script, for example `sudo ./RemoveSystemBanner_macOS.sh`. The configuration is kept.

### Administration

SystemBanner reads the preferences domain `com.systembanner`, with the same keys as the Windows registry values (`Simple`, `0` to `5`, `Text`, `TopAndBottom`, `Debug`). Only computer wide settings count, a user cannot override them in their own preferences.

- On one Mac: System Preferences > SystemBanner (10.6 to 10.11), or Applications > Utilities > SystemBanner Settings (10.12 and later).
- On many Macs (10.7 and later): edit and deploy `Configuration/SystemBanner.mobileconfig` with your MDM (Jamf, Intune, Workspace ONE, etc.), or install it with the Profiles preference pane. This is the counterpart of Group Policy, and it overrides the local settings.
- From Terminal: `sudo defaults write /Library/Preferences/com.systembanner Simple -int 4`, then `sudo chmod 644 /Library/Preferences/com.systembanner.plist`. On 10.6 servers, MCX (Workgroup Manager) can manage the same domain.

Changes apply within about one second. `SystemBanner.app/Contents/MacOS/SystemBanner --diag` prints what SystemBanner sees. With `Debug` set to 1, SystemBanner logs to Console.app.

### Differences with the Windows version

- **No reserved screen space.** macOS has no AppBars: the top banner sits right below the menu bar and the bottom banner right above the Dock, over other windows. Clicks go through the banner, so a title bar under it can still be dragged. Like the bottom banner of Windows sits below the taskbar, the top banner stays below the menu bar, so Spotlight and menus open over it, and the bottom banner below the Dock, so magnified Dock icons show over it.
- **Fullscreen apps are not resized.** When an app covers a whole screen, the banners move to the screen edges and stay over it, but they cover the top and bottom of the app, since resizing other apps would need the Accessibility permission.
- **Login window.** The login window banner uses launchd's pre-login agents. The top banner sits below the strip of status icons (battery, Wi-Fi, user switching) of the main screen. It works on every version tested, see the table above.
- Gatekeeper: the apps are signed ad hoc, not notarized. The installer removes the quarantine flag so they run on recent macOS.

### Building

On a Mac with Xcode or the Command Line Tools:

- `Code/SystemBanner-SnowLeopard-ElCapitan/build.sh` builds `SnowLeopard-ElCapitan/Binaries` (the app and the preference pane). System Preferences of 10.6 and 10.7 runs with Objective-C garbage collection and reopens in 32 bit for a pane that does not support it, which fails without i386 code. Today's compilers cannot build garbage collected code, so the script marks the pane as supporting it, and `SettingsPane.m` is written to run with and without garbage collection. Objective-C with manual memory management, since Swift and ARC cannot target Snow Leopard any more, and only APIs available on 10.6, checked by `-Wunguarded-availability`.
- `Code/SystemBanner-macOS/build.sh` builds both `macOS/Binaries` and `macOS-ARM/Binaries` from the same Swift sources, in the Swift 5 language mode (Swift concurrency needs macOS 10.15).

--------
BUILDING
--------

The project in `Code/SystemBanner` targets .NET Framework 4.0, x86. It builds with Visual Studio 2019 and the .NET Framework 4.0 targeting pack. Visual Studio 2022 no longer ships that targeting pack: add the `Microsoft.NETFramework.ReferenceAssemblies.net40` NuGet package to build it. The binaries in `XP/Binaries` and `Vista-7/Binaries` are the same build: Release, x86, with symbols (`SystemBanner.pdb`).

The Windows 2000 build uses `SystemBanner2000.csproj` in the same folder: same sources, .NET Framework 2.0, x86, with `WIN2000` defined. `Win2000.cs` and the `#if WIN2000` blocks hold its differences (no registry views, no `WTSQueryUserToken`, self installation), and `App2000.config` selects the 2.0 runtime. It needs the .NET Framework 3.5 (which includes 2.0) targeting support, or the `Microsoft.NETFramework.ReferenceAssemblies.net20` NuGet package.

-------
CREDITS
-------

SystemBanner was created by Aaron Wawrzyniak ([awawrzyniak10](https://github.com/awawrzyniak10/SystemBanner)). The Windows 2000, XP, Vista and 7 fork (2000, XP, Vista and 7 ports, logon screen banner, watchdog service, live updates, fullscreen handling) is by Cole. Stock classification colors are based on the GSA form color information collected by Frank Caviggia (https://github.com/fcaviggia/classification-banner).

SystemBanner is released under the MIT License, see `LICENSE`.
