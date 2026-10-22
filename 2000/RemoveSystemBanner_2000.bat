@ECHO OFF & CLS & ECHO.
REM SystemBanner removal for Windows 2000 Professional SP4.
REM Copyright (c) 2026, Cole. MIT License Applies.
NET FILE 1>NUL 2>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] You must run this script from an administrator account. & PAUSE & EXIT /B 1)

ECHO === Removing the service and the Run key, restarting Explorer
"%ProgramFiles%\SystemBanner\SystemBanner.exe" /uninstall
TYPE "%TEMP%\SystemBanner_setup.log"

ECHO === Deleting the files
SET NGEN="%WINDIR%\Microsoft.NET\Framework\v2.0.50727\ngen.exe"
IF EXIST %NGEN% %NGEN% uninstall "%ProgramFiles%\SystemBanner\SystemBanner.exe" /nologo /silent
DEL "%ProgramFiles%\SystemBanner\SystemBanner.exe"
DEL "%ProgramFiles%\SystemBanner\SystemBanner.exe.config"
DEL "%ProgramFiles%\SystemBanner\SystemBanner.pdb"
RMDIR /S /Q "%ProgramFiles%\SystemBanner"
DEL "%WINDIR%\inf\SystemBanner.adm"
PAUSE
