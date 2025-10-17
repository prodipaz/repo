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
:: 6. ADD TO USER PATH (Robust & Error-Logged)
:: -------------------------------------------------------
set "ADD_PATH=C:\ffmpeg\bin"
echo [*] Step 6: Adding %ADD_PATH% to the USER PATH...
echo [*] Step 6: Starting PATH modification. >> "%LOGFILE%"
echo.

:: Read the current user PATH from the registry.
:: We use '2^>nul' to escape the '>' for the 'for' loop and suppress errors if the Path value doesn't exist.
echo [*] Reading current USER PATH from registry... >> "%LOGFILE%"
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul ^| findstr /i "Path"') do set "CURRENT_USER_PATH=%%B"

:: Check if the Path value exists in the registry at all.
if not defined CURRENT_USER_PATH (
    echo [i] USER PATH registry entry not found. It will be created. >> "%LOGFILE%"
    set "CURRENT_USER_PATH="
)

:: Check if the path is already present to prevent duplicates.
:: We use findstr for a case-insensitive check. The >nul suppresses output.
if defined CURRENT_USER_PATH (
    echo [*] Checking if path already exists... >> "%LOGFILE%"
    echo.%CURRENT_USER_PATH%| findstr /i /c:"%ADD_PATH%" >nul
)

:: If findstr returns an errorlevel of 1, the path was not found.
if %errorlevel% neq 0 (
    echo [*] Path not found in USER PATH. Adding it now...
    echo [*] Path not found. Preparing to add. >> "%LOGFILE%"

    :: If the user path is empty, just set it to our new path.
    :: Otherwise, append it with a semicolon.
    if not defined CURRENT_USER_PATH (
        set "NEW_USER_PATH=%ADD_PATH%"
        echo [*] USER PATH was empty. New path will be: %NEW_USER_PATH% >> "%LOGFILE%"
    ) else (
        set "NEW_USER_PATH=%CURRENT_USER_PATH%;%ADD_PATH%"
        echo [*] Appending to existing path. New path will be: >> "%LOGFILE%"
        echo %NEW_USER_PATH% >> "%LOGFILE%"
    )
    
    :: Use 'reg add' to write the new path to the registry.
    :: This is more reliable than 'setx' as it doesn't truncate long paths.
    :: We use REG_EXPAND_SZ which is the correct type for the PATH variable.
    :: ALL output (stdout and stderr) is redirected to the log file for debugging.
    echo [*] Executing reg add command... >> "%LOGFILE%"
    reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "%NEW_USER_PATH%" /f >> "%LOGFILE%" 2>&1
    
    :: Check if the registry update was successful.
    if %errorlevel%==0 (
        echo [✓] Successfully added %ADD_PATH% to the USER PATH.
        echo [✓] Successfully added to USER PATH. >> "%LOGFILE%"
        echo [!] IMPORTANT: You must open a NEW Command Prompt window for this change to take effect.
    ) else (
        echo [X] CRITICAL ERROR: Failed to update the USER PATH.
        echo [X] CRITICAL ERROR: 'reg add' failed with errorlevel %errorlevel%. >> "%LOGFILE%"
        echo [X] Check the end of the log file for the 'reg add' error message. >> "%LOGFILE%"
        echo.
        echo [!] The script will now exit to prevent further issues.
        echo [!] Please check the log file: %LOGFILE%
        goto :EXIT
    )
) else (
    echo [i] %ADD_PATH% already exists in the USER PATH. No changes needed.
    echo [i] Path already exists. No changes made. >> "%LOGFILE%"
)
echo.
echo [*] Step 6: PATH modification complete. >> "%LOGFILE%"
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
