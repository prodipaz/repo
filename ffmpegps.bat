@echo off
setlocal enabledelayedexpansion
title FFmpeg Auto Installer (No PowerShell Required)
echo ======================================================
echo         FFmpeg Auto Installer (with Fallback)
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
set "TMP_PS1=%TEMP%\add_ffmpeg_to_path.ps1"
set "PWSH_EXE="

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
:: 2. DETECT OR ENABLE POWERSHELL
::-------------------------------------------------------
where powershell >nul 2>&1 && set "PWSH_EXE=powershell"
if "%PWSH_EXE%"=="" if exist "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" (
    set "PWSH_EXE=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
)

if "%PWSH_EXE%"=="" (
    echo [!] PowerShell not found on PATH.
    echo [!] Will use fallback methods for download and extract.
) else (
    echo [✓] PowerShell available: %PWSH_EXE%
)
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
:: 4. DOWNLOAD FFMPEG
::-------------------------------------------------------
if exist "%FFMPEG_ZIP%" (
    echo [i] Found existing FFmpeg ZIP, skipping download.
) else (
    echo [1/5] Downloading FFmpeg...
    if not "%PWSH_EXE%"=="" (
        "%PWSH_EXE%" -Command "Invoke-WebRequest '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%' -UseBasicParsing" >nul 2>&1
        if exist "%FFMPEG_ZIP%" (
            echo [✓] Download complete via PowerShell.
        ) else (
            echo [X] PowerShell download failed. Trying bitsadmin...
            bitsadmin /transfer ffmpeg /download /priority normal "%FFMPEG_URL%" "%FFMPEG_ZIP%"
        )
    ) else (
        echo [!] PowerShell not available, using bitsadmin...
        bitsadmin /transfer ffmpeg /download /priority normal "%FFMPEG_URL%" "%FFMPEG_ZIP%"
    )

    if not exist "%FFMPEG_ZIP%" (
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

if not "%PWSH_EXE%"=="" (
    "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ^
        "Expand-Archive -Force -Path '%FFMPEG_ZIP%' -DestinationPath '%INSTALL_DIR%'"
) else (
    echo [!] PowerShell not available, using tar fallback...
    tar -xf "%FFMPEG_ZIP%" -C "C:\" >nul 2>&1
    for /d %%i in ("C:\ffmpeg-*") do (
        move "%%i" "%INSTALL_DIR%" >nul 2>&1
    )
)

if not exist "%INSTALL_DIR%\bin\ffmpeg.exe" (
    echo [X] Extraction failed.
    pause
    exit /b
)
echo [✓] Extraction successful.
echo.

::-------------------------------------------------------
:: 6. ADD TO PATH
::-------------------------------------------------------
set "addPath=%FFMPEG_BIN%"
echo [3/5] Adding FFmpeg to PATH...

if "%IS_ADMIN%"=="1" (
    echo [*] Admin detected → Adding to SYSTEM PATH...
    for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SysPath=%%B"
    echo !SysPath! | findstr /i /c:"%addPath%" >nul
    if !errorlevel! equ 1 (
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path /t REG_EXPAND_SZ /d "!SysPath!;%addPath%" /f >nul
        echo [✓] Added to SYSTEM PATH.
    ) else (
        echo [i] Already in SYSTEM PATH.
    )
) else (
    echo [*] Standard user → Adding to USER PATH...
    echo %PATH% | findstr /i /c:"%addPath%" >nul
    if %errorlevel% equ 1 (
        setx PATH "%PATH%;%addPath%" >nul
        echo [✓] Added to USER PATH.
        echo [!] Please open a NEW Command Prompt to apply changes.
    ) else (
        echo [i] Already in USER PATH.
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
echo.

::-------------------------------------------------------
:: 8. DONE
::-------------------------------------------------------
echo [5/5] All steps completed successfully!
echo [i] FFmpeg ZIP saved at: %FFMPEG_ZIP%
echo [i] Installed in: %INSTALL_DIR%
echo ======================================================
echo [DONE] FFmpeg installation finished successfully!
echo ======================================================
pause
exit /b
