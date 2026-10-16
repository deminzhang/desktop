@echo off
rem Build the XuanDesk GDExtension (..\xuandesk_native.dll).
rem
rem The engine loads this DLL in-process: it owns the WorkerW wallpaper mount, the
rem tray icon, the HUD window styling and the metrics sampler, so the project runs
rem as ONE process - no helper exe, no loopback socket. host.c is the original
rem separate-process implementation, kept as the reference the port was written
rem against; "build.cmd host" still builds it.
rem
rem   build.cmd          release DLL - no debug surface (no breadcrumb log, no test())
rem   build.cmd debug    adds -DXD_DEBUG_LOG: arms _gdext_init.log and the test()
rem                      hook that the gate probes drive
rem   build.cmd host     legacy bin\host.exe
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

rem The tray icon is a compiled-in resource (tray.rc + xuandesk.ico), so windres
rem runs first; it sits beside gcc.
rem
rem windres preprocesses the .rc by running the gcc *beside it*, spelled out with
rem that full path - and a mingw installed under "C:\Program Files\..." therefore
rem comes back unquoted and the command line splits at the space ("preprocessing
rem failed"). Naming gcc bare makes PATH (set above) resolve it instead, and the
rem flags have to be spelled out because --preprocessor replaces the whole
rem command, not just the program.
windres tray.rc -O coff -o ..\tray_res.o --preprocessor="gcc -E -xc-header -DRC_INVOKED"
if errorlevel 1 exit /b 1

if /i "%~1"=="host" goto host

set "DBG="
if /i "%~1"=="debug" set "DBG=-DXD_DEBUG_LOG"
rem __USE_MINGW_ANSI_STDIO: an old mingw (7.x, as shipped in "C:\Program Files\mingw")
rem hands %llu straight to the pre-VS2015 msvcrt, which does not know "ll" - the metric
rem frame's seq/mem/up fields print garbage (T23). Asking for it costs ~29 KB (measured
rem on gcc 15.1.0: 85,016 -> 114,023 B before the tray resource) and is what makes the
rem frame correct on any toolchain, so both links here pass it.
gcc -O2 -shared -Wall -Wextra -Wl,--export-all-symbols %DBG% -D__USE_MINGW_ANSI_STDIO=1 -o ..\xuandesk_native.dll ^
    gdext\xuandesk_native.c -I. -luser32 -lshell32 -ladvapi32 -liphlpapi ..\tray_res.o
if errorlevel 1 (
    del ..\tray_res.o
    exit /b 1
)
del ..\tray_res.o
echo [XuanDesk] built xuandesk_native.dll
endlocal
exit /b 0

:host
if not exist "..\bin" mkdir "..\bin"
rem (same __USE_MINGW_ANSI_STDIO reason as the DLL link above)
gcc -O2 -s -Wall -Wextra -mwindows -D__USE_MINGW_ANSI_STDIO=1 -o ..\bin\host.exe host.c ^
    ..\tray_res.o -lws2_32 -liphlpapi -luser32 -ladvapi32 -lshell32
if errorlevel 1 (
    del ..\tray_res.o
    exit /b 1
)
del ..\tray_res.o
echo [XuanDesk] built bin\host.exe
endlocal
