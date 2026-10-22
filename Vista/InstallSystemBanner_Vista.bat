@ECHO OFF & CLS & ECHO.
REM SystemBanner installer for Windows Vista SP2 (x86 and x64). Requires .NET Framework 4.0 or later 4.x.
REM Copyright (c) 2026, Cole. MIT License Applies.
NET FILE 1>NUL 2>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] Right click this file and select "Run as administrator". & PAUSE & EXIT /B 1)
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
REM Group Policy templates, found by gpedit.msc under Computer Configuration > Administrative Templates > SystemBanner
COPY /Y "%~dp0Group Policy\SystemBanner.admx" "%WINDIR%\PolicyDefinitions\"
COPY /Y "%~dp0Group Policy\en-US\SystemBanner.adml" "%WINDIR%\PolicyDefinitions\en-US\"

ECHO === Precompiling SystemBanner (faster start, mostly on the logon screen)
REM SystemBanner is a 32 bit program, also on 64 bit Windows, so it uses the 32 bit ngen
SET NGEN="%WINDIR%\Microsoft.NET\Framework\v4.0.30319\ngen.exe"
IF EXIST %NGEN% %NGEN% install "%ProgramFiles%\SystemBanner\SystemBanner.exe" /nologo /silent

ECHO === Starting the user banner at logon
REM the service also starts it within 3 sec and restarts it if it is closed or killed
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /V "SystemBanner" /T REG_SZ /D "\"%ProgramFiles%\SystemBanner\SystemBanner.exe\"" /F

ECHO === Installing the SystemBanner service (logon screen banner + watchdog)
REM always create (fails harmlessly with 1073 if it exists) then configure; not "interact", useless since Vista isolates services in session 0
SC CREATE SystemBanner binPath= "\"%ProgramFiles%\SystemBanner\SystemBanner.exe\" /service" start= auto type= own obj= LocalSystem DisplayName= "SystemBanner"
SC CONFIG SystemBanner binPath= "\"%ProgramFiles%\SystemBanner\SystemBanner.exe\" /service" start= auto type= own obj= LocalSystem DisplayName= "SystemBanner"
SC DESCRIPTION SystemBanner "Displays SystemBanner on the logon screen and keeps the user banner running."
SC FAILURE SystemBanner reset= 0 actions= restart/5000/restart/5000/restart/5000
SC START SystemBanner
REM no START of the banner here: from this elevated window it would run as administrator, the service starts it with the user's normal rights

ECHO.
ECHO === Checking the service
PING -n 6 127.0.0.1 1>NUL
SC QUERY SystemBanner | FIND "RUNNING" 1>NUL
IF ERRORLEVEL 1 (ECHO [ERROR] The SystemBanner service is NOT running. Please copy this whole window and send it.) ELSE (ECHO [OK] The SystemBanner service is running and starts the banner. Lock the session with Win+L to see the logon screen banner.)
ECHO.
PAUSE
