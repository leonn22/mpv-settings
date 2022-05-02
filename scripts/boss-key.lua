--[[
  * boss-key.lua v1.0.2
  * (Older versions will lack a version number)
  *
  * AUTHOR: detuur, zaza42
  * License: MIT
  * link: https://github.com/detuur/mpv-scripts
  * 
  * This script minimises and pauses the window when
  * the boss key (default 'b') is pressed.
  * Can be overwriten in input.conf as follows:
  * KEY script-binding boss-key
  * xdotool is required on Xorg(Linux)
--]]

utils = require 'mp.utils'

local platform = windows --set to 'linux', 'windows' or 'macos' to override automatic assign

if platform == 'windows' then
    mp.command_native_async({
        name = "subprocess",
        playback_only = false,
        detach = true,
        args = {'powershell', '-NoProfile', '-Command', [[&{
$bosspid = ]]..utils.getpid()..[[

# Construct the named pipe's name
$pipename = -join('mpv-boss-key-',$bosspid)
$fullpipename = -join("\\.\pipe\", $pipename)

# This will run in a separate thread
$minimizeloop = {
    param($pipename, $bosspid)
    # Create the named pipe
    $pipe = new-object System.IO.Pipes.NamedPipeServerStream($pipename)

    # Compile the Win32 API function call
    $signature='[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $showWindowAsync = Add-Type -memberDefinition $signature -name "Win32ShowWindowAsync" -namespace Win32Functions -passThru

    # The core loop
    while($true) {
        $pipe.WaitForConnection()
        if ($pipe.ReadByte() -ne 109) {
            break 
        }
        $pipe.Disconnect()
        $showWindowAsync::ShowWindowAsync((Get-Process -id $bosspid).MainWindowHandle, 2)
    }
    $pipe.Dispose()
}

# Exiting this monstrosity (THANKS POWERSHELL FOR BROKEN ASYNC) is surprisingly
# cumbersome. It took literal hours to find something that didn't spontaneously
# combust.
$bossproc = Get-Process -pid $bosspid -ErrorAction SilentlyContinue
$exitsequence = {
    &{echo q > $fullpipename} 2> $null
    [Environment]::Exit(0)
}
if ((-Not $bossproc) -or $bossproc.HasExited) { $exitsequence.Invoke() }

# Begin watching for events until boss closes
Start-Job -ScriptBlock $minimizeloop -Name "mpvminloop" -ArgumentList $pipename,$bosspid
while($true) {
    Start-Sleep 1
    if ($bossproc.HasExited) { $exitsequence.Invoke() }
}
}]]}}, function()end)
end

mp.add_key_binding('b', 'boss-key', boss_key)
