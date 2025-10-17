@echo off
setlocal enabledelayedexpansion
title FFmpeg Auto Installer (PowerShell Auto-Fix)
echo ======================================================
echo              FFmpeg Auto Installer
echo ======================================================
echo.

::-------------------------------------------------------
:: CONFIGURATION
::-------------------------------------------------------
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "FFMPEG_ZIP=%TEMP%\ffmpeg-release-essentials.zip"
set "INSTALL_DIR=C:\ffmpeg"
set "FFMPEG_BIN=%INSTALL_DIR%\bin"
set "PWSH_EXE=powershell.exe"
set "PWSH_PATH=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

::-------------------------------------------------------
:: 1. ADMIN CHECK
::-------------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Please run this script as Administrator.
    pause
    exit /b
)

::-------------------------------------------------------
:: 2. CHECK / FIX POWERSHELL AVAILABILITY
::-------------------------------------------------------
echo [✓] Checking PowerShell availability...
%PWSH_EXE% -Command "Write-Host 'PowerShell OK'" >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] 'powershell' command not found in PATH.
    if exist "%PWSH_PATH%" (
        echo [i] Found PowerShell at: %PWSH_PATH%
        echo [i] Temporarily adding to PATH...
        set "PATH=%PATH%;C:\Windows\System32\WindowsPowerShell\v1.0"
        set "PWSH_EXE=%PWSH_PATH%"
    ) else (
        echo [X] PowerShell not found on this system!
        echo     This installer requires PowerShell to run.
        pause
        exit /b
    )
)
echo [✓] PowerShell ready.
echo.

::-------------------------------------------------------
:: 3. CHECK EXISTING FFMPEG
::-------------------------------------------------------
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
:: 4. DOWNLOAD FFMPEG
::-------------------------------------------------------
echo [1/5] Downloading FFmpeg...
"%PWSH_EXE%" -Command "Invoke-WebRequest '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%'" || (
    echo [!] Download failed. Check your internet connection.
    pause
    exit /b
)

::-------------------------------------------------------
:: 5. EXTRACT FFMPEG
::-------------------------------------------------------
echo [2/5] Extracting FFmpeg...
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%"
"%PWSH_EXE%" -Command "Expand-Archive -Force -Path '%FFMPEG_ZIP%' -DestinationPath '%INSTALL_DIR%'"

for /d %%i in ("%INSTALL_DIR%\ffmpeg-*") do set "EXTRACTED_DIR=%%i"
if defined EXTRACTED_DIR (
    xcopy "%EXTRACTED_DIR%\*" "%INSTALL_DIR%\" /e /i /h /y >nul
    rmdir /s /q "%EXTRACTED_DIR%"
)

::-------------------------------------------------------
:: 6. ADD TO SYSTEM PATH
::-------------------------------------------------------
echo [3/5] Adding FFmpeg to system PATH...
"%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ^
"$path = [Environment]::GetEnvironmentVariable('Path','Machine');" ^
"if ($path -notmatch [regex]::Escape('%FFMPEG_BIN%')) {" ^
"    $newPath = $path + ';%FFMPEG_BIN%';" ^
"    [Environment]::SetEnvironmentVariable('Path',$newPath,'Machine');" ^
"    Write-Host '[✓] Added %FFMPEG_BIN% to PATH';" ^
"} else {Write-Host '[i] Already in PATH';}"

if %errorlevel% neq 0 (
    echo [!] Failed to modify system PATH.
    pause
    exit /b
)

::-------------------------------------------------------
:: 7. VERIFY INSTALLATION
::-------------------------------------------------------
echo.
echo [4/5] Verifying installation...
cmd /c "ffmpeg -version"
if %errorlevel% neq 0 (
    echo [!] FFmpeg not recognized yet. Try reopening Command Prompt or restarting your PC.
) else (
    echo [✓] FFmpeg successfully installed and added to PATH.
)

::-------------------------------------------------------
:: 8. CLEANUP
::-------------------------------------------------------
echo.
echo [5/5] Cleaning up...
del "%FFMPEG_ZIP%" >nul 2>&1

echo.
echo ======================================================
echo [DONE] FFmpeg installed in: %INSTALL_DIR%
echo PowerShell verified and used successfully.
echo ======================================================
pause
exit /b
