@echo off
rem Same as run.bat but keeps the console attached so host.exe's output and the
rem engine's are visible. The engine build is a GUI-subsystem binary, so its own
rem stdout only reaches the file it is redirected to - use
rem   run_debug.bat --shot=shots/x.png > tools\run.log 2>&1
rem when the engine's own lines matter.
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
