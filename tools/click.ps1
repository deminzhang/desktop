# Click inside a XuanDesk window by posting mouse messages with explicit client
# coordinates - no cursor involved.
#
# Why not SetCursorPos/mouse_event/SendInput: some other app on this desktop
# warps the cursor continuously (measured: a position set one call earlier is up
# to 170 px off by the time the button message is delivered), and Godot reads
# the *live* cursor position for button events. Posting WM_MOUSEMOVE first makes
# the engine track the coordinates we choose, whatever the real cursor does.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/click.ps1 XuanDesk.HUD 70 264
param(
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][int]$X,
    [Parameter(Mandatory = $true)][int]$Y
)

$ErrorActionPreference = "Stop"

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class Hud {
    public delegate bool EnumProc(IntPtr h, IntPtr l);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);

    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }

    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);

    public static IntPtr Find(string title) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h, l) => {
            StringBuilder sb = new StringBuilder(256);
            if (GetWindowText(h, sb, 256) <= 0) return true;
            if (!sb.ToString().StartsWith(title)) return true;
            // the HUD is a top-level window; the wallpaper one is reparented into
            // WorkerW, so its class is "Engine" either way
            found = h;
            return false;
        }, IntPtr.Zero);
        return found;
    }
}
"@

$h = [Hud]::Find($Title)
if ($h -eq [IntPtr]::Zero) {
    Write-Output "FAIL  no window titled '$Title'"
    exit 1
}

# X,Y are window-relative (Godot's own coordinates), which is what ScreenToClient
# needs after subtracting the window origin
$rect = New-Object Hud+RECT
[void][Hud]::GetWindowRect($h, [ref]$rect)
$pt = New-Object Hud+POINT
$pt.X = $rect.L + $X
$pt.Y = $rect.T + $Y
[void][Hud]::ScreenToClient($h, [ref]$pt)

$WM_MOUSEMOVE = 0x0200
$WM_LBUTTONDOWN = 0x0201
$WM_LBUTTONUP = 0x0202
$MK_LBUTTON = 0x0001

$lparam = [IntPtr](($pt.Y -shl 16) -bor ($pt.X -band 0xFFFF))
[void][Hud]::PostMessage($h, $WM_MOUSEMOVE, [IntPtr]::Zero, $lparam)
Start-Sleep -Milliseconds 60
[void][Hud]::PostMessage($h, $WM_LBUTTONDOWN, [IntPtr]$MK_LBUTTON, $lparam)
Start-Sleep -Milliseconds 60
[void][Hud]::PostMessage($h, $WM_LBUTTONUP, [IntPtr]::Zero, $lparam)

Write-Output "clicked '$Title' at client $($pt.X),$($pt.Y)"
