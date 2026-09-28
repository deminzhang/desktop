@echo off
rem Build the native host (WorkerW wallpaper parenting + metrics stream).
setlocal
cd /d "%~dp0"

where gcc >nul 2>nul
if errorlevel 1 (
    if exist "C:\mingw64\bin\gcc.exe" (
        set "PATH=C:\mingw64\bin;%PATH%"
    ) else (
        echo [XuanDesk] gcc not found. Install mingw-w64 or add it to PATH.
        exit /b 1
    )
)

if not exist "..\bin" mkdir "..\bin"
gcc -O2 -s -Wall -Wextra -mwindows -o ..\bin\host.exe host.c ^
    -lws2_32 -liphlpapi -luser32 -ladvapi32 -lshell32
if errorlevel 1 exit /b 1
echo [XuanDesk] built bin\host.exe
endlocal
