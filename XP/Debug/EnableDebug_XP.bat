@ECHO OFF & CLS & ECHO.
REM SystemBanner debug helper for Windows XP: turns debug logging on, then gathers every log on the Desktop.
REM Copyright (c) 2026, Cole. MIT License Applies.
NET FILE 1>NUL 2>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] You must run this script from an administrator account. & PAUSE & EXIT /B 1)

ECHO === Turning debug logging on
REG ADD "HKLM\SOFTWARE\Policies\SystemBanner" /V Debug /T REG_DWORD /D 1 /F
REM the banners pick the value up by themselves, the service reads it when it starts
SC STOP SystemBanner 1>NUL 2>NUL
PING -n 4 127.0.0.1 1>NUL
SC START SystemBanner 1>NUL

ECHO.
ECHO Debug logging is on. Now reproduce the problem (lock the session with Win+L,
ECHO log off, change the classification, play a fullscreen video...).
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
SC QUERY SystemBanner > "%OUT%\service.txt"
SC QC SystemBanner >> "%OUT%\service.txt"
TASKLIST /V /FI "IMAGENAME eq SystemBanner.exe" > "%OUT%\processes.txt"
REG QUERY "HKLM\SOFTWARE\Policies\SystemBanner" > "%OUT%\settings.txt"
REM SystemBanner events (ID 1902) from the Application event log, eventquery.vbs ships with XP Professional
IF EXIST "%WINDIR%\system32\eventquery.vbs" cscript //nologo "%WINDIR%\system32\eventquery.vbs" /l application /fi "id eq 1902" /fo list /v > "%OUT%\events.txt"

ECHO.
ECHO [OK] Logs gathered in "%OUT%". Send this folder to whoever is helping you.
ECHO Run DisableDebug_XP.bat when you are done.
START "" "%OUT%"
PAUSE
