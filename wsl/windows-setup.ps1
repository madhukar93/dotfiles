# Windows side of the CachyOS WSL setup. Run in an elevated (admin) PowerShell:
#   powershell -ExecutionPolicy Bypass -File \\wsl$\cachyos\home\<user>\.local\share\chezmoi\wsl\windows-setup.ps1
# Add -Uninstall to remove everything it installed. Safe to run again.
param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'

$task        = 'WSL-mount-data-disk'
$mountScript = Join-Path $env:USERPROFILE 'mount-data-disk.ps1'
$wslconfig   = Join-Path $env:USERPROFILE '.wslconfig'
$fontKey     = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$fontZip     = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/0xProto.zip'
$fontStyles  = 'Regular', 'Bold', 'Italic'
$wtSettings  = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'

function Set-TerminalFont([string]$face) {
    if (-not (Test-Path $wtSettings)) { Write-Host "skip  Windows Terminal settings not found"; return }
    Copy-Item $wtSettings "$wtSettings.bak" -Force
    $s = Get-Content $wtSettings -Raw | ConvertFrom-Json
    if (-not $s.profiles.defaults) { $s.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force }
    if ($face) { $s.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{ face = $face }) -Force }
    else { $s.profiles.defaults.PSObject.Properties.Remove('font') }
    $s | ConvertTo-Json -Depth 32 | Set-Content $wtSettings -Encoding UTF8
    Write-Host "done  Windows Terminal default font: $(if ($face) { $face } else { 'removed' }) (backup: settings.json.bak)"
}

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item $mountScript, $wslconfig -ErrorAction SilentlyContinue
    foreach ($s in $fontStyles) {
        Remove-ItemProperty $fontKey "0xProto Nerd Font $s (TrueType)" -ErrorAction SilentlyContinue
        # A font Windows has loaded stays locked until the next sign-in; the registry entry is already gone.
        Remove-Item "$env:WINDIR\Fonts\0xProtoNerdFont-$s.ttf" -ErrorAction SilentlyContinue
    }
    Set-TerminalFont $null
    Write-Host "Removed. Run 'wsl --shutdown' so WSL drops the memory setting. Sign out to unload the font."
    return
}

# 1. /data mount at logon (WSL also starts the task at boot via /etc/wsl.conf)
Copy-Item (Join-Path $PSScriptRoot 'mount-data-disk.ps1') $mountScript -Force
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$mountScript`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
Register-ScheduledTask -TaskName $task -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null
Write-Host "done  task $task runs $mountScript at logon"

# 2. WSL memory limit and default disk size
Copy-Item (Join-Path $PSScriptRoot 'wslconfig') $wslconfig -Force
Write-Host "done  $wslconfig (takes effect after 'wsl --shutdown')"

# 3. Nerd Font for all users (Windows Terminal did not find a per-user install)
$tmp = Join-Path $env:TEMP '0xProto-nerd-font'
New-Item -ItemType Directory $tmp -Force | Out-Null
Invoke-WebRequest $fontZip -OutFile "$tmp\0xProto.zip"
Expand-Archive "$tmp\0xProto.zip" $tmp -Force
foreach ($s in $fontStyles) {
    $f = "0xProtoNerdFont-$s.ttf"
    Copy-Item "$tmp\$f" "$env:WINDIR\Fonts\$f" -Force
    New-ItemProperty $fontKey "0xProto Nerd Font $s (TrueType)" -Value $f -Force | Out-Null
}
Remove-Item $tmp -Recurse -Force
Write-Host "done  0xProto Nerd Font installed for all users"

# 4. Every Windows Terminal tab uses it (the Start-menu CachyOS entry does not use the cachyos profile)
Set-TerminalFont '0xProto Nerd Font'
Write-Host "Restart Windows Terminal (Stop-Process -Name WindowsTerminal) to load the font."
