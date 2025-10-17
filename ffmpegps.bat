@echo off
setlocal enabledelayedexpansion
title FFmpeg Auto Installer (Stable + Persistent)
echo ======================================================
echo       FFmpeg Auto Installer for Windows 11
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
set "PWSH_PATH=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
set "PWSH_EXE=powershell.exe"

::-------------------------------------------------------
:: 1. CHECK ADMIN RIGHTS
::-------------------------------------------------------
net session >nul 2>&1
if %errorlevel%==0 (
    echo [✓] Running as Administrator.
    set "IS_ADMIN=1"
) else (
    echo [i] Running as Standard User (PATH will be added to user only).
    set "IS_ADMIN=0"
)
echo.

::-------------------------------------------------------
:: 2. CHECK POWERSHELL
::-------------------------------------------------------
echo [*] Checking PowerShell...
%PWSH_EXE% -Command "Write-Host 'PowerShell OK'" >nul 2>&1
if %errorlevel% neq 0 (
    if exist "%PWSH_PATH%" (
        echo [i] Found PowerShell at: %PWSH_PATH%
        set "PATH=%PATH%;C:\Windows\System32\WindowsPowerShell\v1.0"
        set "PWSH_EXE=%PWSH_PATH%"
    ) else (
        echo [X] PowerShell not found — fallback to bitsadmin/tar.
        set "PWSH_EXE="
    )
)
if "%PWSH_EXE%"=="" (
    echo [⚠] PowerShell unavailable.
) else (
    echo [✓] PowerShell ready: %PWSH_EXE%
)
echo.

::-------------------------------------------------------
:: 3. PREPARE DOWNLOAD FOLDER
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
    echo [i] FFmpeg ZIP already exists at %FFMPEG_ZIP%
) else (
    echo [1/5] Downloading FFmpeg package...
    if not "%PWSH_EXE%"=="" (
        "%PWSH_EXE%" -Command "Invoke-WebRequest '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%' -UseBasicParsing" >nul 2>&1
        if exist "%FFMPEG_ZIP%" (
            echo [✓] Download complete via PowerShell.
        ) else (
            echo [!] PowerShell download failed — using bitsadmin.
            bitsadmin /transfer ffmpeg /download /priority normal "%FFMPEG_URL%" "%FFMPEG_ZIP%"
        )
    ) else (
        echo [!] PowerShell unavailable — using bitsadmin.
        bitsadmin /transfer ffmpeg /download /priority normal "%FFMPEG_URL%" "%FFMPEG_ZIP%"
    )

    if not exist "%FFMPEG_ZIP%" (
        echo [X] Download failed — please check your internet connection.
        echo Press any key to close.
        pause >nul
        goto :EOF
    )
)
echo.

::-------------------------------------------------------
:: 5. EXTRACT FFMPEG (FIXED EXTRACTION)
::-------------------------------------------------------
echo [2/5] Extracting FFmpeg...

:: Clean up previous installation if it exists
if exist "%INSTALL_DIR%" (
    echo [i] Removing old installation folder...
    rmdir /s /q "%INSTALL_DIR%"
)

:: Extract zip into download directory
if not "%PWSH_EXE%"=="" (
    "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ^
        "Expand-Archive -Force -Path '%FFMPEG_ZIP%' -DestinationPath '%DOWNLOAD_DIR%'" >nul 2>&1
) else (
    echo [!] PowerShell not available, using tar fallback...
    tar -xf "%FFMPEG_ZIP%" -C "%DOWNLOAD_DIR%" >nul 2>&1
)

:: Locate extracted folder
set "EXTRACTED_DIR="
for /d %%i in ("%DOWNLOAD_DIR%\ffmpeg-*") do (
    set "EXTRACTED_DIR=%%i"
)

if not defined EXTRACTED_DIR (
    echo [X] Extraction failed — folder not found in %DOWNLOAD_DIR%.
    echo Press any key to close.
    pause >nul
    goto :EOF
)

:: Move extracted content
echo [i] Moving FFmpeg to %INSTALL_DIR% ...
mkdir "%INSTALL_DIR%" >nul 2>&1
xcopy "!EXTRACTED_DIR!\*" "%INSTALL_DIR%\" /e /i /h /y >nul
rmdir /s /q "!EXTRACTED_DIR!"

if not exist "%INSTALL_DIR%\bin\ffmpeg.exe" (
    echo [X] Extraction failed — ffmpeg.exe not found.
    echo Press any key to close.
    pause >nul
    goto :EOF
)

echo [✓] Extraction completed successfully.
echo.

::-------------------------------------------------------
:: 6. ADD TO PATH
::-------------------------------------------------------
set "addPath=%FFMPEG_BIN%"
echo [3/5] Adding FFmpeg to PATH...

if "%IS_ADMIN%"=="1" (
    echo [*] Adding to SYSTEM PATH...
    for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SysPath=%%B"
    echo !SysPath! | findstr /i /c:"%addPath%" >nul
    if !errorlevel! equ 1 (
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path /t REG_EXPAND_SZ /d "!SysPath!;%addPath%" /f >nul
        echo [✓] Added to SYSTEM PATH.
    ) else (
        echo [i] Already in SYSTEM PATH.
    )
) else (
    echo [*] Adding to USER PATH...
    echo %PATH% | findstr /i /c:"%addPath%" >nul
    if %errorlevel% equ 1 (
        setx PATH "%PATH%;%addPath%" >nul
        echo [✓] Added to USER PATH.
        echo [!] Open a NEW Command Prompt for the change to take effect.
    ) else (
        echo [i] Already in USER PATH.
    )
)
echo.

::-------------------------------------------------------
:: 7. VERIFY INSTALLATION
::-------------------------------------------------------
echo [4/5] Verifying installation...
cmd /c "ffmpeg -version" >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] FFmpeg not recognized yet. Try reopening Command Prompt or restart your PC.
) else (
    echo [✓] FFmpeg installed successfully and recognized.
)
echo.

::-------------------------------------------------------
:: 8. COMPLETE
::-------------------------------------------------------
echo [5/5] Installation complete!
echo [i] FFmpeg location: %INSTALL_DIR%
echo [i] ZIP saved at: %FFMPEG_ZIP%
echo ------------------------------------------------------
echo [DONE] FFmpeg installation finished successfully!
echo ------------------------------------------------------
echo.
echo Press any key to exit.
pause >nul
endlocal
exit /b
