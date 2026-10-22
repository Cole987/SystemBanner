@ECHO OFF & CLS & ECHO.
REM SystemBanner debug helper for Windows 2000: turns debug logging on, then gathers every log on the Desktop.
REM Copyright (c) 2026, Cole. MIT License Applies.
NET FILE 1>NUL 2>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] You must run this script from an administrator account. & PAUSE & EXIT /B 1)

ECHO === Turning debug logging on
REM Windows 2000 has no reg.exe: regedit imports the value
REGEDIT /S "%~dp0Debug_On.reg"
REM the banners pick the value up by themselves, the service reads it when it starts
NET STOP SystemBanner 1>NUL 2>NUL
NET START SystemBanner 1>NUL 2>NUL

ECHO.
ECHO Debug logging is on. Now reproduce the problem (lock the computer with
ECHO Ctrl+Alt+Del, log off, change the classification, play a fullscreen video...).
ECHO When you are done, come back to this window and press a key to gather the logs.
ECHO.
PAUSE

SET OUT=%USERPROFILE%\Desktop\SystemBanner_logs
ECHO === Gathering logs in "%OUT%"
IF NOT EXIST "%OUT%\service" MKDIR "%OUT%\service"
IF NOT EXIST "%OUT%\user" MKDIR "%OUT%\user"
REM crash and debug logs: service and logon screen banner (SYSTEM) / user banner (this account)
COPY /Y "%WINDIR%\Temp\SystemBanner_*.log" "%OUT%\service\" 1>NUL 2>NUL
COPY /Y "%TEMP%\SystemBanner_*.log" "%OUT%\user\" 1>NUL 2>NUL
REM service state, running SystemBanner processes and settings (Windows 2000 has no sc.exe nor tasklist.exe)
"%ProgramFiles%\SystemBanner\SystemBanner.exe" /diag
COPY /Y "%USERPROFILE%\Desktop\SystemBanner_diag.txt" "%OUT%\" 1>NUL 2>NUL

ECHO.
ECHO [OK] Logs gathered in "%OUT%". Send this folder to whoever is helping you.
ECHO SystemBanner events are in Event Viewer, Application log, event ID 1902.
ECHO Run DisableDebug_2000.bat when you are done.
START "" "%OUT%"
PAUSE
