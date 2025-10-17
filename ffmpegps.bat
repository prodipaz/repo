@echo off
setlocal enabledelayedexpansion
title FFmpeg Auto Installer (Auto PATH Version)
echo ======================================================
echo             FFmpeg Auto Installer (Auto PATH)
echo ======================================================
echo.

::-------------------------------------------------------
:: CONFIGURATION
::-------------------------------------------------------
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "DOWNLOAD_DIR=C:\ffmpegdownload"
set "FFMPEG_ZIP=%DOWNLOAD_DIR%\ffmpeg-release-essentials.zip"
set "INSTALL_DIR=C:\ffmpeg"
set "FFMPEG_BIN=%INSTALL_DIR%\bin"
set "PWSH_EXE=powershell.exe"
set "TMP_PS1=%TEMP%\add_ffmpeg_to_path.ps1"

::-------------------------------------------------------
:: 1. CHECK ADMIN RIGHTS
::-------------------------------------------------------
net session >nul 2>&1
if %errorlevel%==0 (
    set "IS_ADMIN=1"
    echo [✓] Running as Administrator.
) else (
    set "IS_ADMIN=0"
    echo [i] Running as Standard User.
)
echo.

::-------------------------------------------------------
:: 2. CHECK POWERSHELL
::-------------------------------------------------------
echo [*] Checking PowerShell...
%PWSH_EXE% -Command "Write-Host 'PowerShell OK'" >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] PowerShell not found. Please install PowerShell first.
    pause
    exit /b
)
echo [✓] PowerShell ready.
echo.

::-------------------------------------------------------
:: 3. ENSURE DOWNLOAD DIRECTORY
::-------------------------------------------------------
if not exist "%DOWNLOAD_DIR%" (
    echo [*] Creating download folder: %DOWNLOAD_DIR%
    mkdir "%DOWNLOAD_DIR%" >nul 2>&1
)
echo [✓] Download folder ready: %DOWNLOAD_DIR%
echo.

::-------------------------------------------------------
:: 4. DOWNLOAD FFMPEG IF NEEDED
::-------------------------------------------------------
if exist "%FFMPEG_ZIP%" (
    echo [i] Found existing FFmpeg ZIP: %FFMPEG_ZIP%
    echo [✓] Skipping download.
) else (
    echo [1/5] Downloading FFmpeg stable build...
    "%PWSH_EXE%" -Command ^
        "Write-Host '  -> Downloading...';" ^
        "Invoke-WebRequest '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%' -UseBasicParsing;" ^
        "if (Test-Path '%FFMPEG_ZIP%') {Write-Host '  -> Download complete.'} else {Write-Host '  -> Download failed.'; exit 1}"
    if %errorlevel% neq 0 (
        echo [X] Download failed. Check your internet connection.
        pause
        exit /b
    )
)
echo.

::-------------------------------------------------------
:: 5. EXTRACT FFMPEG
::-------------------------------------------------------
echo [2/5] Extracting FFmpeg to %INSTALL_DIR% ...
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%"

"%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ^
    "Expand-Archive -Force -Path '%FFMPEG_ZIP%' -DestinationPath '%INSTALL_DIR%'; Write-Host '  -> Extracted archive.'"

:: Detect extracted folder (it’s usually ffmpeg-*-essentials_build)
set "EXTRACTED_DIR="
for /d %%i in ("%INSTALL_DIR%\ffmpeg-*") do (
    set "EXTRACTED_DIR=%%i"
)

if defined EXTRACTED_DIR (
    echo [i] Moving contents from !EXTRACTED_DIR! ...
    xcopy "!EXTRACTED_DIR!\*" "%INSTALL_DIR%\" /e /i /h /y >nul
    rmdir /s /q "!EXTRACTED_DIR!"
) else (
    echo [!] Could not find extracted folder — check zip contents.
    pause
    exit /b
)

::-------------------------------------------------------
:: 6. ADD TO PATH (AUTO MODE)
::-------------------------------------------------------
echo [3/5] Adding FFmpeg to PATH...
set "ESC_BIN=%FFMPEG_BIN:\=\\%>"
set "addPath=%FFMPEG_BIN%"

if "%IS_ADMIN%"=="1" (
    echo [*] Admin detected → Adding to SYSTEM PATH...

    > "%TMP_PS1%" (
        echo $ffpath = "%ESC_BIN%"
        echo $envPath = [Environment]::GetEnvironmentVariable('Path','Machine')
        echo if (-not ($envPath -match [regex]::Escape($ffpath))) {
        echo     [Environment]::SetEnvironmentVariable('Path', $envPath + ';' + $ffpath, 'Machine')
        echo     Write-Host "[✓] Added $ffpath to SYSTEM PATH"
        echo } else {
        echo     Write-Host "[i] FFmpeg already in SYSTEM PATH"
        echo }
    )

    "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%TMP_PS1%"
    del "%TMP_PS1%" >nul 2>&1

) else (
    echo [*] Standard user → Adding to USER PATH...

    echo %PATH% | findstr /i /c:"%addPath%" >nul
    if %errorlevel% equ 1 (
        echo Adding "%addPath%" to your USER PATH environment variable...
        setx PATH "%PATH%;%addPath%"
        if %errorlevel% equ 0 (
            echo [✓] Successfully added to USER PATH.
            echo IMPORTANT: You must open a NEW Command Prompt window for the changes to take effect.
        ) else (
            echo [X] Failed to update USER PATH.
        )
    ) else (
        echo [i] The path "%addPath%" is already in your USER PATH.
    )
)
echo.

::-------------------------------------------------------
:: 7. VERIFY INSTALLATION
::-------------------------------------------------------
echo [4/5] Verifying installation...
cmd /c "ffmpeg -version"
if %errorlevel% neq 0 (
    echo [!] FFmpeg not recognized yet. Try reopening Command Prompt or restarting your PC.
) else (
    echo [✓] FFmpeg successfully installed and added to PATH.
)

::-------------------------------------------------------
:: 8. DONE
::-------------------------------------------------------
echo.
echo [5/5] All steps completed successfully!
echo [i] FFmpeg ZIP saved at: %FFMPEG_ZIP%
echo [i] Installed in: %INSTALL_DIR%
echo ======================================================
echo [DONE] FFmpeg installation finished successfully!
echo ======================================================
pause
exit /b
