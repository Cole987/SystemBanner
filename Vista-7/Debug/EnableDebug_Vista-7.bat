@ECHO OFF & CLS & ECHO.
REM SystemBanner debug helper for Windows Vista and 7: turns debug logging on, then gathers every log on the Desktop.
REM Copyright (c) 2026, Cole. MIT License Applies.
NET FILE 1>NUL 2>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] Right click this file and select "Run as administrator". & PAUSE & EXIT /B 1)

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
REM crash and debug logs: service and logon screen banners (SYSTEM) / user banner (this account)
COPY /Y "%WINDIR%\Temp\SystemBanner_*.log" "%OUT%\service\" 1>NUL 2>NUL
COPY /Y "%TEMP%\SystemBanner_*.log" "%OUT%\user\" 1>NUL 2>NUL
SC QUERY SystemBanner > "%OUT%\service.txt"
SC QC SystemBanner >> "%OUT%\service.txt"
TASKLIST /V /FI "IMAGENAME eq SystemBanner.exe" > "%OUT%\processes.txt"
QUERY SESSION > "%OUT%\sessions.txt" 2>&1
REG QUERY "HKLM\SOFTWARE\Policies\SystemBanner" > "%OUT%\settings.txt"
REM SystemBanner events (ID 1902) from the Application event log, newest first
WEVTUTIL QE Application /q:"*[System[(EventID=1902)]]" /f:text /rd:true /c:500 > "%OUT%\events.txt" 2>&1
REM what SystemBanner reads in the registry, as this account
"%ProgramFiles%\SystemBanner\SystemBanner.exe" /diag
COPY /Y "%USERPROFILE%\Desktop\SystemBanner_diag.txt" "%OUT%\" 1>NUL 2>NUL

ECHO.
ECHO [OK] Logs gathered in "%OUT%". Send this folder to whoever is helping you.
ECHO Run DisableDebug_Vista-7.bat when you are done.
START "" "%OUT%"
PAUSE
