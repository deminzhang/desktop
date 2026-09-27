@echo off
rem Launch XuanDesk: 3D wallpaper plus the floating HUD.
rem The wallpaper window is parented into the desktop's WorkerW layer by
rem bin\host.exe, which is why it ends up *behind* the desktop icons.
rem
rem The runtime is the installed Godot editor build (Steam's
rem godot.windows.opt.tools.64.exe), found below or given as GODOT=<path>.
rem tools\ must not hold an engine copy: see README「环境与工具链」.
setlocal
cd /d "%~dp0"

if not defined GODOT call :find_godot
if not defined GODOT (
    echo [XuanDesk] Godot 4.7 not found. Set GODOT to godot.windows.opt.tools.64.exe,
    echo            e.g. set "GODOT=E:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
    exit /b 1
)
if not exist "%~dp0bin\host.exe" (
    echo [XuanDesk] bin\host.exe missing - run native\build.cmd
    exit /b 1
)

start "" "%GODOT%" --path "%~dp0." -- --wallpaper=1 --fps=60
exit /b 0

:find_godot
rem The Steam install, on whichever drive Steam was put on.
for %%D in (C D E F G H) do call :try "%%D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
for %%D in (C D E F G H) do call :try "%%D:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
for %%D in (C D E F G H) do call :try "%%D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
for %%D in (C D E F G H) do call :try "%%D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
for %%D in (C D E F G H) do call :try "%%D:\Games\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
exit /b 0

:try
if not defined GODOT if exist %1 set "GODOT=%~1"
exit /b 0
