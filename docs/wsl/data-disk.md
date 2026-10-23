# The /data disk

Goal: a second NVMe drive (Corsair MP600 Elite 1 TB) that holds toolchains and projects, mounted at `/data`,
and later reused by a bare-metal Linux install.

## What was built

- One GPT partition, type "Linux filesystem", partition name `data`, ext4 with label `data`
  (`mkfs.ext4 -L data -O ^orphan_file`). The partition type means Windows ignores it. `^orphan_file` keeps the
  filesystem readable by older Linux versions.
- `wsl --mount \\.\PHYSICALDRIVE<n> --partition 1 --type ext4 --name data` mounts it at `/mnt/wsl/data`.
  `/data` is a symlink to that.
- `wsl/mount-data-disk.ps1` finds the disk **by model name**, not by number, because Windows disk numbers
  change when drives are added.
- Mounted again at every Windows logon (Task Scheduler task `WSL-mount-data-disk`, highest privileges) **and**
  at every WSL start (`[boot] command` in `/etc/wsl.conf` starts the same task).

## Why this way

`wsl --mount` needs administrator rights and **does not persist**: the disk is detached when the WSL virtual
machine stops (`wsl --shutdown`, or after all windows close). A non-admin process may *start* an existing task
that is set to run with highest privileges, so the WSL boot command can trigger the admin task without a prompt.
This is the approach a WSL maintainer recommended in microsoft/WSL issue #6073 ("running wsl --mount at
startup is the simplest way").

## Alternatives considered

The logon-only task was tried and failed. The others were found in research (microsoft/WSL issue #6073 and a
community gist), judged against this setup, and not tried.

| Alternative | Why not |
|---|---|
| Logon task only | Worked until the first `wsl --shutdown`; then `/data` was a broken link until the next Windows logon. This was the first version and it failed. |
| Registry "Run" key | Mounting needs admin; reported not to work in the issue |
| `sudo wsl.exe` or `powershell.exe` from a shell profile | Needs passwordless sudo or shows a Windows admin prompt (UAC) on every start |
| Task trigger on Hyper-V event 18500 ("VM started") | The log it reads does not exist on this PC |
| `/etc/fstab` entry | Only helps once the disk is already attached to WSL |

## Failures met along the way, and what each taught

1. **`mkfs.ext4` said the device does not exist.** The command line used `$D-part` instead of `$D-part1`.
   Lesson: read the error text; it printed the path it tried.
2. **After "mount" the disk was not there.** `dmesg` showed `EXT4-fs (sdf1): VFS: Can't find ext4 filesystem`:
   the formatting had not run. Lesson: the kernel log says what WSL tried and why it failed.
3. **The boot command ran but did nothing.** The kernel-side process list showed a dead `schtasks.exe` and the
   task's `LastRunTime` was older than the WSL start. The likely cause is that WSL splits `command =` on spaces
   and ignores quotes, so `/tn "WSL mount data disk"` passed wrong arguments (inferred; not confirmed in
   Microsoft's documentation). After the task was renamed to `WSL-mount-data-disk` the same line worked.
   Lesson: run the exact command line yourself first
   (`cmd=$(sed -n 's/^command *= *//p' /etc/wsl.conf); bash -c "$cmd"`), and compare `LastRunTime` of the task
   with the time WSL started.
4. **Device letters change** (`sdf1`, then `sde1`). Nothing depends on them; the script and the mount name do.
5. **A freshly built program was all zeros.** On 2026-10-22, `cargo install` of sudo-mcp left
   `~/.cargo/bin/sudo-mcp` empty and the build output on `/data` full of zero bytes; starting it failed with
   `ENOEXEC`. At the next boot the WSL system disk reported `10 orphan inodes deleted`, so WSL had stopped
   uncleanly (cause inferred, not confirmed). A scan of all 111,567 files changed on `/data` since 2026-10-20
   found no other zero-filled file. Lesson: run `sync` after large writes and before deleting an original,
   and stop WSL with `wsl --shutdown`.

## Troubleshooting `/data`

| Symptom | Check | Fix |
|---|---|---|
| `/data` is a broken link | `findmnt /mnt/wsl/data` prints nothing | `schtasks.exe /run /tn WSL-mount-data-disk` |
| The task did not run at WSL start | Compare `uptime -s` with the task's `LastRunTime`; check the `command =` line in `/etc/wsl.conf` | Fix the line; `wsl --shutdown` |
| The task ran but mounting failed | Run `powershell.exe -File C:\Users\<you>\mount-data-disk.ps1` in an admin shell and read the error | The script stops if it finds zero or several disks matching the model |
| `Can't find ext4 filesystem` in `dmesg` | `lsblk -o NAME,FSTYPE,LABEL` | The partition has no filesystem; format it |
| Mount works but you cannot write | `ls -ld /mnt/wsl/data` | `sudo chown $USER: /mnt/wsl/data` |

## Before booting Linux natively from this disk (dual boot)

Turn off Windows hibernation and Fast Startup first: `powercfg /h off` in an admin PowerShell. Fast Startup
is a partial hibernation and `powercfg /h off` disables both. If Windows hibernates while WSL has this disk
mounted, the ext4 filesystem stays mounted inside the saved WSL state. Mounting it from native Linux and then
resuming Windows lets two systems write to one filesystem, which corrupts it. With hibernation off, a reboot
always stops WSL and detaches the disk. Check with `powercfg /a`: "Hibernation has not been enabled".

Both installs also need the same user ID (`id -u`, 1000 here), or every file on `/data` belongs to another
user.

## Safety rules used

Identify the disk by size and model, never by device letter alone, and show it to the user before any
command that erases it. Disks 0 (Windows) and the games disk were never touched.
