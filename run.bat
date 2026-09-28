@echo off
rem Launch XuanDesk: 3D aquarium as the desktop wallpaper plus the floating HUD.
rem The aquarium window is parented into the desktop's WorkerW layer by
rem bin\host.exe, which is why it ends up *behind* the desktop icons.
setlocal
cd /d "%~dp0"

set "GODOT=%~dp0tools\godot.exe"
if not exist "%GODOT%" set "GODOT=%~dp0tools\godot_console.exe"
if not exist "%GODOT%" (
    echo [XuanDesk] Godot runtime missing at tools\godot.exe
    exit /b 1
)
if not exist "%~dp0bin\host.exe" (
    echo [XuanDesk] bin\host.exe missing - run native\build.cmd
    exit /b 1
)

start "" "%GODOT%" --path "%~dp0." -- --wallpaper=1 --fps=60
endlocal
