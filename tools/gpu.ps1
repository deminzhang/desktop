# Runs a background live and reports what it costs the GPU, with two instruments
# at once, because on this machine either one alone has misled us (计划 §2.4 T14/T16):
#
#   * nvidia-smi, the whole card - which is the honest one, but it includes every
#     other process on the machine (an emulator, four browsers, ...) and it goes to
#     100 % whenever the card is shared, which says nothing about us;
#   * the Windows GPU Engine counters, which are per-process but spiky: a frame of
#     a few milliseconds lands in one sample and misses the next (T14), so read the
#     average over many samples, never a single reading or a peak.
#
# Both numbers are only comparable taken on a quiet machine. Check nvidia-smi's
# process list first - if someone else holds the card, absolute frame rates from
# any run here are meaningless (the ratio between two backgrounds still holds).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/gpu.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/gpu.ps1 -Background aquarium -Samples 10
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/gpu.ps1 -Stop
param(
    [string]$Background = "sky",
    [string]$Rate = "1",
    [string]$Hud = "1",
    [string]$Wallpaper = "1",
    [string]$SkyTime = "",
    [string]$Fps = "60",
    [int]$Samples = 15,
    [switch]$Stop
)
$ErrorActionPreference = "Continue"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$log = Join-Path $env:LOCALAPPDATA "XuanDesk\host.log"

function Show-Procs() {
    $found = @(Get-Process godot, godot_console, host -ErrorAction SilentlyContinue)
    $found | Select-Object Id, ProcessName, StartTime | Format-Table -AutoSize | Out-String
    return $found.Count
}

function Stop-Procs() {
    @(Get-Process godot, godot_console, host -ErrorAction SilentlyContinue) |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

if ($Stop) { Stop-Procs; Write-Output ("left: " + (Show-Procs)); exit 0 }

$app = @("--path", $root, "--", "--wallpaper=$Wallpaper", "--background=$Background",
        "--sky-rate=$Rate", "--hud=$Hud", "--fps=$Fps")
if ($SkyTime -ne "") { $app += "--sky-time=$SkyTime" }

Write-Output "=== $Background, rate=$Rate, hud=$Hud, wallpaper=$Wallpaper, fps=$Fps ==="
$godot = Join-Path $root "tools\godot_console.exe"
$proc = Start-Process -FilePath $godot -PassThru -ArgumentList $app
Start-Sleep -Seconds 8

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "tools\check_wallpaper.ps1")
Write-Output ("host.log: " + (Select-String -Path $log -Pattern "host start:" |
        Select-Object -Last 1).Line)

$renderer = Get-Process godot -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $renderer) { Write-Output "no renderer process found"; Stop-Procs; exit 1 }

$smi = (Get-Command nvidia-smi -ErrorAction SilentlyContinue).Source
$paths = @((Get-Counter -ListSet 'GPU Engine').PathsWithInstances |
        Where-Object { $_ -like "*pid_$($renderer.Id)*" -and
            $_ -like "*utilization percentage" })
if ($paths.Count -eq 0) { Write-Output "no GPU engine counters for pid $($renderer.Id)" }

$per = @()
for ($i = 0; $i -lt $Samples; $i++) {
    $hit = (Get-Counter -Counter $paths -ErrorAction SilentlyContinue).CounterSamples
    $sum = 0.0
    if ($hit) { $sum = ($hit | Measure-Object -Property CookedValue -Sum).Sum }
    $card = "n/a"
    $vram = "n/a"
    if ($smi) {
        $card = (& $smi --query-gpu=utilization.gpu,memory.used,memory.total `
                --format=csv,noheader,nounits) -join " / "
    }
    $per += [math]::Round($sum, 3)
    Write-Output ("sample {0,2}: our pid {1,7:N3} %   card {2}" -f $i, $sum, $card)
    Start-Sleep -Seconds 1
}

$stat = $per | Measure-Object -Average -Maximum
Write-Output ("pid {0}: average {1:N3} %, peak {2:N3} % over {3} samples" -f `
        $renderer.Id, $stat.Average, $stat.Maximum, $per.Count)

Write-Output "=== quit through ctrl+alt+q ==="
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Q {
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
"@
[Q]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero)
[Q]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 120
[Q]::keybd_event(0x51, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 150
[Q]::keybd_event(0x51, 0, 2, [UIntPtr]::Zero)
[Q]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
[Q]::keybd_event(0x11, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Seconds 5
Write-Output ("processes left after ctrl+alt+q: " + (Show-Procs))
