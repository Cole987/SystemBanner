@ECHO OFF & CLS & ECHO.
REM SystemBanner removal for Windows XP SP3 (x86).
REM Copyright (c) 2026, Cole. MIT License Applies.
NET FILE 1>NUL 2>NUL
IF ERRORLEVEL 1 (ECHO You must run this script from an administrator account. & PAUSE & EXIT /B 1)

REM no more automatic restarts, then stop and delete the service
SC FAILURE SystemBanner reset= 0 actions= "" 1>NUL 2>NUL
SC STOP SystemBanner
PING -n 3 127.0.0.1 1>NUL
SC DELETE SystemBanner
TASKKILL /F /IM SystemBanner.exe
REM restart Explorer to clean up the screen space reserved by the AppBars
TASKKILL /F /IM explorer.exe
START explorer.exe

SET NGEN="%WINDIR%\Microsoft.NET\Framework\v4.0.30319\ngen.exe"
IF EXIST %NGEN% %NGEN% uninstall "%ProgramFiles%\SystemBanner\SystemBanner.exe" /nologo /silent
REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /V "SystemBanner" /F
DEL "%ProgramFiles%\SystemBanner\SystemBanner.exe"
DEL "%ProgramFiles%\SystemBanner\SystemBanner.exe.config"
RMDIR /S /Q "%ProgramFiles%\SystemBanner"
DEL "%WINDIR%\inf\SystemBanner.adm"
PAUSE
