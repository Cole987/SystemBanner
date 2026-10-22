@ECHO OFF & CLS & ECHO.
REM SystemBanner removal for Windows Vista SP2 (x86 and x64).
REM Copyright (c) 2026, Cole. MIT License Applies.
NET FILE 1>NUL 2>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] Right click this file and select "Run as administrator". & PAUSE & EXIT /B 1)

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
DEL "%ProgramFiles%\SystemBanner\SystemBanner.pdb"
RMDIR /S /Q "%ProgramFiles%\SystemBanner"
DEL "%WINDIR%\PolicyDefinitions\SystemBanner.admx"
DEL "%WINDIR%\PolicyDefinitions\en-US\SystemBanner.adml"
PAUSE
