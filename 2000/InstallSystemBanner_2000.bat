@ECHO OFF & CLS & ECHO.
REM SystemBanner installer for Windows 2000 Professional SP4. Requires .NET Framework 2.0.
REM Copyright (c) 2026, Cole. MIT License Applies.
REM Windows 2000 has no sc.exe, reg.exe nor taskkill.exe: SystemBanner.exe /stop and /install do that work.
NET FILE 1>NUL 2>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] You must run this installer from an administrator account. & PAUSE & EXIT /B 1)
IF NOT EXIST "%WINDIR%\Microsoft.NET\Framework\v2.0.50727\mscorwks.dll" (ECHO [ERROR] .NET Framework 2.0 is not installed. Install it, then run this installer again. & PAUSE & EXIT /B 1)
IF NOT EXIST "%~dp0Binaries\SystemBanner.exe" (ECHO [ERROR] "%~dp0Binaries\SystemBanner.exe" not found. & PAUSE & EXIT /B 1)

ECHO === Stopping any running SystemBanner
"%~dp0Binaries\SystemBanner.exe" /stop
TYPE "%TEMP%\SystemBanner_setup.log"
PING -n 3 127.0.0.1 1>NUL

ECHO === Copying files to "%ProgramFiles%\SystemBanner"
IF NOT EXIST "%ProgramFiles%\SystemBanner" MKDIR "%ProgramFiles%\SystemBanner"
COPY /Y "%~dp0Binaries\SystemBanner.exe" "%ProgramFiles%\SystemBanner\"
COPY /Y "%~dp0Binaries\SystemBanner.exe.config" "%ProgramFiles%\SystemBanner\"
REM symbols, so crash logs show line numbers
COPY /Y "%~dp0Binaries\SystemBanner.pdb" "%ProgramFiles%\SystemBanner\"
REM Group Policy template, add it in gpedit.msc > Administrative Templates > Add/Remove Templates
COPY /Y "%~dp0SystemBanner.adm" "%WINDIR%\inf\"

ECHO === Precompiling SystemBanner (faster start, mostly on the logon screen)
SET NGEN="%WINDIR%\Microsoft.NET\Framework\v2.0.50727\ngen.exe"
IF EXIST %NGEN% %NGEN% install "%ProgramFiles%\SystemBanner\SystemBanner.exe" /nologo /silent

ECHO === Installing the Run key and the SystemBanner service (logon screen banner + watchdog)
"%ProgramFiles%\SystemBanner\SystemBanner.exe" /install
IF ERRORLEVEL 1 (TYPE "%TEMP%\SystemBanner_setup.log" & ECHO. & ECHO [ERROR] Installation failed. Please copy this whole window and send it. & PAUSE & EXIT /B 1)
TYPE "%TEMP%\SystemBanner_setup.log"
ECHO.
PAUSE
