# Show the desktop (minimize everything), capture it, then restore the session.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/capture_desktop_clear.ps1 out.png
param([string]$Out = "shots/desktop_clear.png", [double]$Settle = 2.0)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$shell = New-Object -ComObject Shell.Application
$shell.MinimizeAll()
Start-Sleep -Seconds $Settle

try {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
    $gfx.Dispose()
    $bmp.Dispose()
    Write-Output "saved $Out"
} finally {
    $shell.UndoMinimizeAll()
    Write-Output "session restored"
}
