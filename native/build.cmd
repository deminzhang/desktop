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
rem The tray icon is a compiled-in resource (tray.rc + xuandesk.ico), so windres
rem runs first; it sits beside gcc.
rem
rem windres preprocesses the .rc by running the gcc *beside it*, spelled out with
rem that full path - and a mingw installed under "C:\Program Files\..." therefore
rem comes back unquoted and the command line splits at the space ("preprocessing
rem failed"). Naming gcc bare makes PATH (set above) resolve it instead, and the
rem flags have to be spelled out because --preprocessor replaces the whole
rem command, not just the program.
windres tray.rc -O coff -o tray_res.o --preprocessor="gcc -E -xc-header -DRC_INVOKED"
if errorlevel 1 exit /b 1
rem __USE_MINGW_ANSI_STDIO: recent mingw-w64 gcc defaults to its own printf, but an
rem older one (7.x, as shipped in "C:\Program Files\mingw") hands %llu straight to
rem msvcrt, which does not know "ll" - the metric frame's seq/mem/up fields print
rem garbage. Asking for it explicitly is a no-op on the new toolchains.
gcc -O2 -s -Wall -Wextra -mwindows -D__USE_MINGW_ANSI_STDIO=1 -o ..\bin\host.exe host.c tray_res.o ^
    -lws2_32 -liphlpapi -luser32 -ladvapi32 -lshell32
if errorlevel 1 (
    del tray_res.o
    exit /b 1
)
del tray_res.o
echo [XuanDesk] built bin\host.exe
endlocal
