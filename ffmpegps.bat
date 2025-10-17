@echo off
setlocal enabledelayedexpansion
title FFmpeg Auto Installer with Progress Bar (Windows 11 Safe Version)

echo ======================================================
echo        FFmpeg Auto Installer with Progress Bar
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
set "BAR_CHAR=#"
set "BAR_LEN=40"

::-------------------------------------------------------
:: UTILITY: PROGRESS BAR
::-------------------------------------------------------
:Progress
set /a percent=%1
setlocal enabledelayedexpansion
set /a filled=%percent% * %BAR_LEN% / 100
set "bar="
for /L %%i in (1,1,!filled!) do set "bar=!bar!%BAR_CHAR%"
for /L %%i in (!filled!,1,%BAR_LEN%) do set "bar=!bar!."
<nul set /p="[%bar%] %percent%%% "
endlocal
exit /b

::-------------------------------------------------------
:: SAFETY: WINDOW STAYS OPEN ON ALL ERRORS
::-------------------------------------------------------
echo [*] Initializing installer...
timeout /t 1 >nul
echo.

::-------------------------------------------------------
:: 1. CHECK ADMIN RIGHTS
::-------------------------------------------------------
net session >nul 2>&1
if %errorlevel%==0 (
    echo [✓] Running as Administrator.
    set "IS_ADMIN=1"
) else (
    echo [i] Running as Standard User (PATH will be user-level).
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
        echo [!] PowerShell not found — fallback to bitsadmin/tar.
        set "PWSH_EXE="
    )
)
if "%PWSH_EXE%"=="" (
    echo [⚠] PowerShell unavailable.
) else (
    echo [✓] PowerShell ready.
)
echo.

::-------------------------------------------------------
:: 3. PREPARE DOWNLOAD FOLDER
::-------------------------------------------------------
if not exist "%DOWNLOAD_DIR%" (
    echo [*] Creating download folder: %DOWNLOAD_DIR%
    mkdir "%DOWNLOAD_DIR%" >nul 2>&1
)
if not exist "%DOWNLOAD_DIR%" (
    echo [X] Failed to create %DOWNLOAD_DIR%. Check permissions.
    pause
    goto :END
)
echo [✓] Download folder ready.
echo.

::-------------------------------------------------------
:: 4. DOWNLOAD FFMPEG (WITH SIMULATED PROGRESS)
::-------------------------------------------------------
if exist "%FFMPEG_ZIP%" (
    echo [i] FFmpeg ZIP already exists.
) else (
    echo [1/5] Downloading FFmpeg...
    if not "%PWSH_EXE%"=="" (
        echo     Using PowerShell for download...
        "%PWSH_EXE%" -Command "Invoke-WebRequest '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%' -UseBasicParsing" >nul 2>&1
    ) else (
        echo     Using bitsadmin (no progress available)...
        bitsadmin /transfer ffmpeg /download /priority normal "%FFMPEG_URL%" "%FFMPEG_ZIP%"
    )
)
if not exist "%FFMPEG_ZIP%" (
    echo [X] Download failed! Check connection or permissions.
    pause
    goto :END
)
echo [✓] Download complete.
echo.

::-------------------------------------------------------
:: 5. EXTRACT FFMPEG (WITH VISUAL PROGRESS)
::-------------------------------------------------------
echo [2/5] Extracting FFmpeg files...
if exist "%INSTALL_DIR%" (
    echo [i] Removing old installation...
    rmdir /s /q "%INSTALL_DIR%"
)
if not "%PWSH_EXE%"=="" (
    "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ^
        "Expand-Archive -Force -Path '%FFMPEG_ZIP%' -DestinationPath '%DOWNLOAD_DIR%'" >nul 2>&1
) else (
    tar -xf "%FFMPEG_ZIP%" -C "%DOWNLOAD_DIR%" >nul 2>&1
)

set "EXTRACTED_DIR="
for /d %%i in ("%DOWNLOAD_DIR%\ffmpeg-*") do set "EXTRACTED_DIR=%%i"

if not defined EXTRACTED_DIR (
    echo [X] Extraction failed (no folder found in %DOWNLOAD_DIR%).
    pause
    goto :END
)

echo     Copying files:
for /L %%P in (0,10,100) do (
    call :Progress %%P
    timeout /t 1 >nul
    if %%P==100 echo.
)
mkdir "%INSTALL_DIR%" >nul 2>&1
xcopy "!EXTRACTED_DIR!\*" "%INSTALL_DIR%\" /e /i /h /y >nul
rmdir /s /q "!EXTRACTED_DIR!"
if not exist "%INSTALL_DIR%\bin\ffmpeg.exe" (
    echo [X] Extraction failed — ffmpeg.exe not found.
    pause
    goto :END
)
echo [✓] Extraction successful.
echo.

::-------------------------------------------------------
:: 6. ADD TO PATH
::-------------------------------------------------------
set "addPath=%FFMPEG_BIN%"
echo [3/5] Adding FFmpeg to PATH...
if "%IS_ADMIN%"=="1" (
    echo     Adding to SYSTEM PATH...
    for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SysPath=%%B"
    echo !SysPath! | findstr /i /c:"%addPath%" >nul
    if !errorlevel! equ 1 (
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path /t REG_EXPAND_SZ /d "!SysPath!;%addPath%" /f >nul
        echo [✓] Added to SYSTEM PATH.
    ) else (
        echo [i] Already in SYSTEM PATH.
    )
) else (
    echo     Adding to USER PATH...
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
    echo [!] FFmpeg not recognized yet — reopen Command Prompt or restart.
) else (
    echo [✓] FFmpeg installed and working.
)
echo.

::-------------------------------------------------------
:: 8. DONE
::-------------------------------------------------------
echo [5/5] Installation complete!
echo ------------------------------------------------------
echo [✓] Installed to: %INSTALL_DIR%
echo [✓] ZIP saved at: %FFMPEG_ZIP%
echo ------------------------------------------------------
echo.
echo Press any key to exit...
pause >nul

:END
endlocal
pause
exit /b
