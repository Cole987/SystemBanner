@ECHO OFF & CLS & ECHO.
REM SystemBanner debug helper for Windows 2000: turns debug logging off.
REM Copyright (c) 2026, Cole. MIT License Applies.
NET FILE 1>NUL 2>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] You must run this script from an administrator account. & PAUSE & EXIT /B 1)

ECHO === Turning debug logging off
REM Windows 2000 has no reg.exe: regedit removes the value
REGEDIT /S "%~dp0Debug_Off.reg"
REM the banners pick the change up by themselves, the service reads it when it starts
NET STOP SystemBanner 1>NUL 2>NUL
NET START SystemBanner 1>NUL 2>NUL

ECHO.
ECHO [OK] Debug logging is off. Crash logs are still written if SystemBanner ever crashes.
PAUSE
