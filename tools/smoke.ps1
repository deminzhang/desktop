# Smoke test for bin/host.exe: listen on loopback, launch the host, print the JSON stream.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/smoke.ps1
param(
    [int]$Port = 47821,
    [int]$Seconds = 5,
    [int]$Wallpaper = 0,
    [string]$Exe = ".\bin\host.exe",
    [string]$Title = "XuanDesk"
)

$ErrorActionPreference = "Stop"
$exePath = (Resolve-Path $Exe).Path
Write-Output "host: $exePath"

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exePath
$psi.Arguments = "--connect 127.0.0.1:$Port --title $Title --wallpaper $Wallpaper --interval 500"
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $false
$proc = [System.Diagnostics.Process]::Start($psi)

$client = $listener.AcceptTcpClient()
$stream = $client.GetStream()
$reader = New-Object System.IO.StreamReader($stream)

$deadline = (Get-Date).AddSeconds($Seconds)
$count = 0
while ((Get-Date) -lt $deadline) {
    if ($stream.DataAvailable) {
        $line = $reader.ReadLine()
        if ($line) { Write-Output $line; $count++ }
    } else {
        Start-Sleep -Milliseconds 40
    }
}

$client.Close()
$listener.Stop()
Start-Sleep -Milliseconds 800
Write-Output "frames=$count  hostExited=$($proc.HasExited)"
if (-not $proc.HasExited) { $proc.Kill() }
