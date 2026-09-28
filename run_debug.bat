@echo off
rem Same as run.bat but keeps a console attached so engine + host output is visible.
setlocal
cd /d "%~dp0"

set "GODOT=%~dp0tools\godot_console.exe"
if not exist "%GODOT%" set "GODOT=%~dp0tools\godot.exe"

"%GODOT%" --path "%~dp0." -- %*
endlocal
