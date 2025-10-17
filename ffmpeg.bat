@echo off
setlocal enabledelayedexpansion
title FFmpeg Auto Installer v2 (Based on PhoenixNAP Tutorial)
echo ======================================================
echo              FFmpeg Auto Installer v2
echo ======================================================
echo.

::-------------------------------------------------------
:: CONFIGURATION
::-------------------------------------------------------
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "FFMPEG_ZIP=%TEMP%\ffmpeg-release-essentials.zip"
set "INSTALL_DIR=C:\ffmpeg"
set "FFMPEG_BIN=%INSTALL_DIR%\bin"

::-------------------------------------------------------
:: STEP 1: Check Administrator Privileges
::-------------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Please run this script as Administrator.
    pause
    exit /b
)

::-------------------------------------------------------
:: STEP 2: Check if FFmpeg already installed
::-------------------------------------------------------
echo Checking for existing FFmpeg installation...
where ffmpeg >nul 2>&1
if %errorlevel%==0 (
    for /f "delims=" %%v in ('ffmpeg -version 2^>nul ^| findstr /r "^ffmpeg"') do set "FFMPEG_VER=%%v"
    echo [i] Existing FFmpeg detected:
    echo     !FFMPEG_VER!
    echo.
    choice /m "Do you want to reinstall FFmpeg?"
    if errorlevel 2 (
        echo [✓] Keeping existing FFmpeg installation.
        pause
        exit /b
    )
)

::-------------------------------------------------------
:: STEP 3: Download FFmpeg ZIP
::-------------------------------------------------------
echo [1/5] Downloading FFmpeg from:
echo     %FFMPEG_URL%
echo.
powershell -Command "Invoke-WebRequest '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%'" || (
    echo [!] Download failed. Please check your internet connection.
    pause
    exit /b
)

::-------------------------------------------------------
:: STEP 4: Extract to C:\ffmpeg
::-------------------------------------------------------
echo [2/5] Extracting files to %INSTALL_DIR% ...
if exist "%INSTALL_DIR%" (
    echo [i] Removing old FFmpeg directory...
    rmdir /s /q "%INSTALL_DIR%"
)
powershell -Command "Expand-Archive -Force -Path '%FFMPEG_ZIP%' -DestinationPath '%INSTALL_DIR%'"

:: Detect inner extracted folder (usually ffmpeg-2025-xx-xx-essentials_build)
for /d %%i in ("%INSTALL_DIR%\ffmpeg-*") do set "EXTRACTED_DIR=%%i"
if defined EXTRACTED_DIR (
    echo [i] Moving extracted contents...
    xcopy "%EXTRACTED_DIR%\*" "%INSTALL_DIR%\" /e /i /h /y >nul
    rmdir /s /q "%EXTRACTED_DIR%"
)

::-------------------------------------------------------
:: STEP 5: Add FFmpeg to PATH safely
::-------------------------------------------------------
echo [3/5] Updating system PATH variable...
for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%B"

echo !SYS_PATH! | find /i "%FFMPEG_BIN%" >nul
if %errorlevel%==0 (
    echo [i] FFmpeg path already exists in PATH.
) else (
    setx /M PATH "!SYS_PATH!;%FFMPEG_BIN%" >nul
    echo [✓] Added %FFMPEG_BIN% to system PATH.
)

::-------------------------------------------------------
:: STEP 6: Verify installation
::-------------------------------------------------------
echo.
echo [4/5] Verifying installation...
cmd /c "ffmpeg -version"
if %errorlevel% neq 0 (
    echo [!] FFmpeg not recognized yet. Try reopening Command Prompt or restarting PC.
) else (
    echo [✓] FFmpeg successfully installed and ready to use.
)

::-------------------------------------------------------
:: STEP 7: Cleanup
::-------------------------------------------------------
echo.
echo [5/5] Cleaning up temporary files...
del "%FFMPEG_ZIP%" >nul 2>&1

echo.
echo ======================================================
echo [DONE] FFmpeg installation completed successfully!
echo You can now use: ffmpeg -version
echo ======================================================
pause
exit /b
