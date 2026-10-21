# Attach the Corsair MP600 ELITE data disk to WSL and mount its ext4 partition at /mnt/wsl/data.
# Run at logon with highest privileges (Task Scheduler task "WSL-mount-data-disk", see windows-setup.ps1).
# The disk is found by model, not by number, because Windows disk numbers can change when drives are added.
$disk = @(Get-Disk | Where-Object FriendlyName -like '*MP600 ELITE*')
if ($disk.Count -ne 1) { throw "Expected one Corsair MP600 ELITE disk, found $($disk.Count)" }
wsl.exe --mount "\\.\PHYSICALDRIVE$($disk[0].Number)" --partition 1 --type ext4 --name data
