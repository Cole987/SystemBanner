@ECHO OFF & CLS & ECHO.
REM SystemBanner installer for Windows XP SP3 (x86). Requires .NET Framework 4.0.
REM Copyright (c) 2026, Cole. MIT License Applies.
NET FILE 1>NUL 2>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] You must run this installer from an administrator account. & PAUSE & EXIT /B 1)
REG QUERY "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Client" /V Install 1>NUL 2>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] .NET Framework 4.0 is not installed. Install it, then run this installer again. & PAUSE & EXIT /B 1)
IF NOT EXIST "%~dp0Binaries\SystemBanner.exe" (ECHO [ERROR] "%~dp0Binaries\SystemBanner.exe" not found. & PAUSE & EXIT /B 1)

ECHO === Stopping any running SystemBanner
SC STOP SystemBanner 1>NUL 2>NUL
PING -n 3 127.0.0.1 1>NUL
TASKKILL /F /IM SystemBanner.exe 1>NUL 2>NUL

ECHO === Copying files to "%ProgramFiles%\SystemBanner"
IF NOT EXIST "%ProgramFiles%\SystemBanner" MKDIR "%ProgramFiles%\SystemBanner"
COPY /Y "%~dp0Binaries\SystemBanner.exe" "%ProgramFiles%\SystemBanner\"
COPY /Y "%~dp0Binaries\SystemBanner.exe.config" "%ProgramFiles%\SystemBanner\"
REM symbols, so crash logs show line numbers
COPY /Y "%~dp0Binaries\SystemBanner.pdb" "%ProgramFiles%\SystemBanner\"
REM XP Group Policy template, add it in gpedit.msc > Administrative Templates > Add/Remove Templates
COPY /Y "%~dp0SystemBanner.adm" "%WINDIR%\inf\"

ECHO === Precompiling SystemBanner (faster start, mostly on the logon screen)
SET NGEN="%WINDIR%\Microsoft.NET\Framework\v4.0.30319\ngen.exe"
IF EXIST %NGEN% %NGEN% install "%ProgramFiles%\SystemBanner\SystemBanner.exe" /nologo /silent

ECHO === Starting the user banner at logon
REM the service also restarts it if it is closed or killed
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /V "SystemBanner" /T REG_SZ /D "\"%ProgramFiles%\SystemBanner\SystemBanner.exe\"" /F

ECHO === Installing the SystemBanner service (logon screen banner + watchdog)
REM XP's SC QUERY does not set ERRORLEVEL for a missing service, so always create (fails harmlessly with 1073 if it exists) then configure
SC CREATE SystemBanner binPath= "\"%ProgramFiles%\SystemBanner\SystemBanner.exe\" /service" start= auto type= own type= interact obj= LocalSystem DisplayName= "SystemBanner"
SC CONFIG SystemBanner binPath= "\"%ProgramFiles%\SystemBanner\SystemBanner.exe\" /service" start= auto type= own type= interact obj= LocalSystem DisplayName= "SystemBanner"
SC DESCRIPTION SystemBanner "Displays SystemBanner on the logon screen and keeps the user banner running."
SC FAILURE SystemBanner reset= 0 actions= restart/5000/restart/5000/restart/5000
SC START SystemBanner

START "" "%ProgramFiles%\SystemBanner\SystemBanner.exe"

ECHO.
ECHO === Checking the service
PING -n 4 127.0.0.1 1>NUL
SC QUERY SystemBanner | FIND "RUNNING" 1>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] The SystemBanner service is NOT running. Please copy this whole window and send it.) ELSE (ECHO [OK] The SystemBanner service is running. Lock the session with Win+L to see the logon screen banner.)
ECHO.
PAUSE
