# Verify that the wallpaper window really sits in the desktop's WorkerW layer,
# i.e. *behind* the desktop icons (Progman).
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/check_wallpaper.ps1
param([string]$Title = "XuanDesk.Aquarium")

$ErrorActionPreference = "Stop"

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class W {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    public static extern IntPtr GetParent(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(IntPtr hWndParent, EnumProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

function Class-Of([IntPtr]$h) {
    if ($h -eq [IntPtr]::Zero) { return "<none>" }
    $sb = New-Object System.Text.StringBuilder 256
    [void][W]::GetClassName($h, $sb, 256)
    return $sb.ToString()
}
function Text-Of([IntPtr]$h) {
    if ($h -eq [IntPtr]::Zero) { return "" }
    $sb = New-Object System.Text.StringBuilder 256
    [void][W]::GetWindowText($h, $sb, 256)
    return $sb.ToString()
}

# Every top-level window, plus its descendants: a reparented wallpaper window is
# no longer top-level, so FindWindow() would miss it.
$script:all = New-Object System.Collections.ArrayList
$script:walk = $null
$script:walk = [W+EnumProc]{
    param([IntPtr]$h, [IntPtr]$l)
    [void]$script:all.Add($h)
    [void][W]::EnumChildWindows($h, $script:walk, [IntPtr]::Zero)
    return $true
}
[void][W]::EnumWindows($script:walk, [IntPtr]::Zero)

# top-to-bottom z-order of top-level windows only
$script:z = New-Object System.Collections.ArrayList
$cb = [W+EnumProc]{
    param([IntPtr]$h, [IntPtr]$l)
    [void]$script:z.Add($h)
    return $true
}
[void][W]::EnumWindows($cb, [IntPtr]::Zero)

$hwnd = [IntPtr]::Zero
foreach ($h in $script:all) {
    # Godot appends " (DEBUG)" to the title in debug builds
    if ((Text-Of $h).StartsWith($Title)) { $hwnd = $h; break }
}
if ($hwnd -eq [IntPtr]::Zero) {
    Write-Output "FAIL  window '$Title' not found in any window (including children)"
    exit 1
}

$parent = [W]::GetParent($hwnd)
$rect = New-Object W+RECT
[void][W]::GetWindowRect($hwnd, [ref]$rect)

Write-Output ("window      : hwnd={0} visible={1}" -f $hwnd, [W]::IsWindowVisible($hwnd))
Write-Output ("rect        : {0},{1} {2}x{3}" -f $rect.Left, $rect.Top,
    ($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top))
Write-Output ("parent      : {0} class={1}" -f $parent, (Class-Of $parent))

$progmanIdx = -1
$progman = [IntPtr]::Zero
$parentIdx = -1
$workerIdx = @()
for ($i = 0; $i -lt $script:z.Count; $i++) {
    $h = $script:z[$i]
    $cls = Class-Of $h
    if ($cls -eq "Progman") {
        $progmanIdx = $i
        $progman = $h
    }
    if ($cls -eq "WorkerW") { $workerIdx += $i }
    if ($h -eq $parent) { $parentIdx = $i }
}
Write-Output ("z-order     : Progman@index {0}, WorkerW at {1}, our parent@index {2} (0 = topmost)" -f `
    $progmanIdx, ($workerIdx -join ","), $parentIdx)

$cls = Class-Of $parent
if ($cls -ne "WorkerW") {
    Write-Output "FAIL  parent class is '$cls', expected WorkerW - the window is NOT behind the desktop icons"
    exit 2
}

if ($parentIdx -ge 0 -and $progmanIdx -ge 0 -and $parentIdx -gt $progmanIdx) {
    Write-Output "OK    aquarium is parented into WorkerW and sits BELOW Progman (desktop icons stay on top)"
    exit 0
}

# Windows 11 nests the wallpaper WorkerW inside Progman as a sibling of the icon
# host, so it never shows up in the top-level z-order. Check Progman's children.
$script:kids = New-Object System.Collections.ArrayList
$kidCb = [W+EnumProc]{
    param([IntPtr]$h, [IntPtr]$l)
    [void]$script:kids.Add($h)
    return $true
}
[void][W]::EnumChildWindows($progman, $kidCb, [IntPtr]::Zero)
$defIdx = -1
$workerKidIdx = -1
for ($i = 0; $i -lt $script:kids.Count; $i++) {
    $c = Class-Of $script:kids[$i]
    if ($c -eq "SHELLDLL_DefView" -and $defIdx -lt 0) { $defIdx = $i }
    if ($script:kids[$i] -eq $parent) { $workerKidIdx = $i }
}
Write-Output ("progman kids: DefView@index {0}, our WorkerW@index {1} (0 = topmost child)" -f `
    $defIdx, $workerKidIdx)
if ($workerKidIdx -ge 0 -and $defIdx -ge 0 -and $workerKidIdx -gt $defIdx) {
    Write-Output "OK    aquarium is nested in Progman's wallpaper WorkerW, BELOW SHELLDLL_DefView (icons stay on top)"
    exit 0
}
Write-Output "WARN  parented into WorkerW but the layer order could not be confirmed"
exit 3
