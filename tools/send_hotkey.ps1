# Fire the global HUD hotkey (Ctrl+Alt+H) so the toggle path can be verified
# without touching the keyboard.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class K {
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
"@

$KEYUP = 0x0002
$VK_CONTROL = 0x11
$VK_MENU = 0x12
$VK_H = 0x48

[K]::keybd_event($VK_CONTROL, 0, 0, [UIntPtr]::Zero)
[K]::keybd_event($VK_MENU, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 120
[K]::keybd_event($VK_H, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 150
[K]::keybd_event($VK_H, 0, $KEYUP, [UIntPtr]::Zero)
[K]::keybd_event($VK_MENU, 0, $KEYUP, [UIntPtr]::Zero)
[K]::keybd_event($VK_CONTROL, 0, $KEYUP, [UIntPtr]::Zero)
Write-Output "sent ctrl+alt+h"
