@ECHO OFF & CLS & ECHO.
REM SystemBanner debug helper for Windows Vista and 7: turns debug logging off.
REM Copyright (c) 2026, Cole. MIT License Applies.
NET FILE 1>NUL 2>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] Right click this file and select "Run as administrator". & PAUSE & EXIT /B 1)

ECHO === Turning debug logging off
REG DELETE "HKLM\SOFTWARE\Policies\SystemBanner" /V Debug /F
REM the banners pick the change up by themselves, the service reads it when it starts
SC STOP SystemBanner 1>NUL 2>NUL
PING -n 4 127.0.0.1 1>NUL
SC START SystemBanner 1>NUL

ECHO.
ECHO [OK] Debug logging is off. Crash logs are still written if SystemBanner ever crashes.
PAUSE
