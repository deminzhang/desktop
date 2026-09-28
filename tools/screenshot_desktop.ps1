# Capture the primary monitor so the aquarium's placement relative to the
# desktop icons can be inspected visually.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/screenshot_desktop.ps1 out.png
param([string]$Out = "shots/desktop.png")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$gfx.Dispose()
$bmp.Dispose()
Write-Output "saved $Out ($($bounds.Width)x$($bounds.Height))"
