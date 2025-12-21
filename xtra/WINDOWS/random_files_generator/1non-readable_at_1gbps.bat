@echo off
color 04
:: Clear screen
cls
echo ===============================
echo     Choose a Console Color
echo ===============================
echo.
echo                 8 = Gray
echo 1 = Blue        9 = Light Blue
echo 2 = Green       A = Light Green
echo 3 = Aqua        B = Light Aqua
echo 4 = Red         C = Light Red
echo 5 = Purple      D = Light Purple
echo 6 = Yellow      E = Light Yellow
echo 7 = White       F = Bright White
echo.

:choose
set /p userColor="Enter text color code (0-9,A-F) [default=1]: "

:: If input is empty, use default
if "%userColor%"=="" set userColor=1

:: Convert to uppercase to simplify validation
set userColor=%userColor:~0,1%
for %%C in (0 1 2 3 4 5 6 7 8 9 A B C D E F) do (
    if /i "%userColor%"=="%%C" set valid=1
)

if not defined valid (
    echo Invalid choice. Please enter 0-9 or A-F.
    set valid=
    goto choose
)

:: Apply color (text only, background = black)
color %userColor%
cls

rem === Get the folder where the batch file is running ===
set "BATCH_DIR=%~dp0"

rem === Default PS1 file in the same folder ===
set "DEFAULT_PATH=%BATCH_DIR%1non-readable_at_1gbps.ps1"

echo                     ============================================
echo                              Random File Generator
echo                     ============================================
echo.
echo             Default script path: "%DEFAULT_PATH%"
echo.
echo                 if u rename the files then default doesn't work,
echo                 u need to give full path of the file.
echo.

set /p "INPUT=Enter path to PS1 (press Enter to use default) > "
rem === Determine target path ===
if "%INPUT%"=="" (
    set "TARGET=%DEFAULT_PATH%"
) else (
    set "TARGET=%INPUT%"
)

rem === Clean up quotes and expand env vars ===
for %%I in ("%TARGET%") do set "TARGET=%%~I"
call set "TARGET=%TARGET%"

rem === Check file existence ===
if not exist "%TARGET%" (
    echo.
    echo File not found: "%TARGET%"
    pause
    exit /b 1
)

echo.
echo Running: "%TARGET%"
echo.
rem === Run Main script ===
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TARGET%"

echo.
echo Done. Press any key to exit.
pause >nul
exit /b 0
