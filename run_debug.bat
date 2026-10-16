@echo off
rem Same as run.bat but keeps the console attached so the engine's own output is
rem visible. It is a GUI-subsystem binary, so its stdout only reaches the file it
rem is redirected to - use
rem   run_debug.bat --shot=.tmp/shots/x.png > .tmp\tools\run.log 2>&1
rem when the engine's own lines matter. The native side writes its breadcrumbs to
rem _gdext_init.log instead, and only when the DLL was built with
rem   native\build.cmd debug
rem (a release DLL has no logging and no test() hook at all).
setlocal
cd /d "%~dp0"

if not defined GODOT call :find_godot
if not defined GODOT (
    echo [XuanDesk] Godot 4.7 not found. Set GODOT to godot.windows.opt.tools.64.exe.
    exit /b 1
)

"%GODOT%" --path "%~dp0." -- %*
exit /b 0

:find_godot
for %%D in (C D E F G H) do call :try "%%D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
for %%D in (C D E F G H) do call :try "%%D:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
for %%D in (C D E F G H) do call :try "%%D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
for %%D in (C D E F G H) do call :try "%%D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
for %%D in (C D E F G H) do call :try "%%D:\Games\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
exit /b 0

:try
if not defined GODOT if exist %1 set "GODOT=%~1"
exit /b 0
