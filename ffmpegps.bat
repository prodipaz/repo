@echo off
setlocal enabledelayedexpansion
title FFmpeg Auto Installer - Safe Debug Mode

echo ======================================================
echo        FFmpeg Auto Installer (Safe Debug)
echo ======================================================
echo.
echo [*] Script started at %date% %time%
echo.

:: -------------------------------------------------------
:: 0. SAFETY: KEEP WINDOW OPEN
:: -------------------------------------------------------
set "PAUSE_ON_EXIT=1"
goto :MAIN

:EXIT
if "%PAUSE_ON_EXIT%"=="1" (
    echo.
    echo [!] Script finished or failed. Press any key to exit...
    pause >nul
)
exit /b

:MAIN
:: -------------------------------------------------------
:: CONFIGURATION
:: -------------------------------------------------------
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "DOWNLOAD_DIR=C:\ffmpegdownload"
set "FFMPEG_ZIP=%DOWNLOAD_DIR%\ffmpeg-release-essentials.zip"
set "INSTALL_DIR=C:\ffmpeg"
set "FFMPEG_BIN=%INSTALL_DIR%\bin"
set "PWSH_EXE=powershell.exe"

:: -------------------------------------------------------
:: LOGGING UTILITY
:: -------------------------------------------------------
set "LOGFILE=%~dp0ffmpeg_install_log.txt"
echo [*] Logging to: %LOGFILE%
echo [*] If anything fails, check this file.
echo ------------------------------------------ >> "%LOGFILE%"
echo START %date% %time% >> "%LOGFILE%"
echo ------------------------------------------ >> "%LOGFILE%"
echo.

:: -------------------------------------------------------
:: 1. CHECK ADMIN RIGHTS
:: -------------------------------------------------------
net session >nul 2>&1
if %errorlevel%==0 (
    echo [✓] Running as Administrator.
    echo [✓] Running as Administrator. >> "%LOGFILE%"
    set "IS_ADMIN=1"
) else (
    echo [i] Running as Standard User.
    echo [i] Running as Standard User. >> "%LOGFILE%"
    set "IS_ADMIN=0"
)
echo.

:: -------------------------------------------------------
:: 2. CHECK POWERSHELL
:: -------------------------------------------------------
echo [*] Checking PowerShell...
%PWSH_EXE% -Command "Write-Host 'PowerShell OK'" >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] PowerShell not found or broken.
    echo [X] PowerShell not found or broken. >> "%LOGFILE%"
    echo [!] Trying to add default path...
    set "PATH=%PATH%;C:\Windows\System32\WindowsPowerShell\v1.0"
)
%PWSH_EXE% -Command "Write-Host 'PowerShell OK'" >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] PowerShell still not working. >> "%LOGFILE%"
    echo [!] Skipping PowerShell usage.
    set "PWSH_EXE="
) else (
    echo [✓] PowerShell ready.
    echo [✓] PowerShell ready. >> "%LOGFILE%"
)
echo.

:: -------------------------------------------------------
:: 3. PREPARE DOWNLOAD DIR
:: -------------------------------------------------------
if not exist "%DOWNLOAD_DIR%" (
    echo [*] Creating %DOWNLOAD_DIR%
    mkdir "%DOWNLOAD_DIR%" >nul 2>&1
)
if not exist "%DOWNLOAD_DIR%" (
    echo [X] Cannot create %DOWNLOAD_DIR%.
    echo [X] Cannot create %DOWNLOAD_DIR%. >> "%LOGFILE%"
    goto :EXIT
)
echo [✓] Download folder ready.
echo.

:: -------------------------------------------------------
:: 4. DOWNLOAD FFMPEG
:: -------------------------------------------------------
if exist "%FFMPEG_ZIP%" (
    echo [i] FFmpeg ZIP already exists.
    echo [i] FFmpeg ZIP already exists. >> "%LOGFILE%"
) else (
    echo [*] Downloading FFmpeg...
    echo [*] Downloading FFmpeg... >> "%LOGFILE%"
    if not "%PWSH_EXE%"=="" (
        "%PWSH_EXE%" -Command "try {Invoke-WebRequest '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%' -UseBasicParsing} catch {exit 1}" >> "%LOGFILE%" 2>&1
    ) else (
        bitsadmin /transfer ffmpeg /download /priority normal "%FFMPEG_URL%" "%FFMPEG_ZIP%" >> "%LOGFILE%" 2>&1
    )
)
if not exist "%FFMPEG_ZIP%" (
    echo [X] Download failed. Check internet or permissions.
    echo [X] Download failed. >> "%LOGFILE%"
    goto :EXIT
)
echo [✓] Download complete.
echo.

:: -------------------------------------------------------
:: 5. EXTRACT FFMPEG
:: -------------------------------------------------------
echo [*] Extracting FFmpeg...
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%"
if not "%PWSH_EXE%"=="" (
    "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ^
        "Expand-Archive -Force -Path '%FFMPEG_ZIP%' -DestinationPath '%DOWNLOAD_DIR%'" >> "%LOGFILE%" 2>&1
) else (
    tar -xf "%FFMPEG_ZIP%" -C "%DOWNLOAD_DIR%" >> "%LOGFILE%" 2>&1
)

for /d %%i in ("%DOWNLOAD_DIR%\ffmpeg-*") do set "EXTRACTED_DIR=%%i"
if not defined EXTRACTED_DIR (
    echo [X] Extraction failed — folder not found.
    echo [X] Extraction failed. >> "%LOGFILE%"
    goto :EXIT
)

mkdir "%INSTALL_DIR%" >nul 2>&1
xcopy "!EXTRACTED_DIR!\*" "%INSTALL_DIR%\" /e /i /h /y >nul
rmdir /s /q "!EXTRACTED_DIR!"
if not exist "%INSTALL_DIR%\bin\ffmpeg.exe" (
    echo [X] ffmpeg.exe not found.
    echo [X] ffmpeg.exe not found. >> "%LOGFILE%"
    goto :EXIT
)
echo [✓] Extraction successful.
echo.

:: -------------------------------------------------------
:: 6. ADD TO PATH
:: -------------------------------------------------------
set "addPath=%FFMPEG_BIN%"
echo [*] Adding FFmpeg to PATH...
echo [*] Adding FFmpeg to PATH... >> "%LOGFILE%"
echo %PATH% | findstr /i /c:"%addPath%" >nul
if %errorlevel% equ 1 (
    setx PATH "%PATH%;%addPath%" >> "%LOGFILE%" 2>&1
    echo [✓] Added to user PATH. Open new CMD to apply.
    echo [✓] Added to user PATH. >> "%LOGFILE%"
) else (
    echo [i] Already in PATH.
    echo [i] Already in PATH. >> "%LOGFILE%"
)
echo.

:: -------------------------------------------------------
:: 7. VERIFY
:: -------------------------------------------------------
echo [*] Checking ffmpeg -version...
cmd /c "ffmpeg -version" >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] FFmpeg not recognized (new window needed).
    echo [!] FFmpeg not recognized (new window needed). >> "%LOGFILE%"
) else (
    echo [✓] FFmpeg installed successfully.
    echo [✓] FFmpeg installed successfully. >> "%LOGFILE%"
)
goto :EXIT
