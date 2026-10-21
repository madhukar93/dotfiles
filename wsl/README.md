# CachyOS on WSL: machine setup outside $HOME

chezmoi does not deploy this folder (see `.chezmoiignore`). It holds the pieces that live in `/etc` or on the
Windows side, and the steps to install or remove them. Everything under `$HOME` (fish's `conf.d/wsl.fish`,
`data-links`, `niri-wsl`, niri and Noctalia config, the VSCodium flatpak override) is ordinary chezmoi state.

| File | Goes to | What it does |
|---|---|---|
| `wsl.conf` | `/etc/wsl.conf` | systemd on; interop on; at every WSL start, runs the `WSL-mount-data-disk` task so `/data` is mounted |
| `wslconfig` | `%USERPROFILE%\.wslconfig` | gives WSL 48 GB of RAM (default is half) |
| `mount-data-disk.ps1` | `%USERPROFILE%\mount-data-disk.ps1` | finds the data disk by model and runs `wsl --mount ... --partition 1 --name data` → `/mnt/wsl/data` |
| `windows-setup.ps1` | run once, elevated | installs or removes the three Windows pieces above plus the 0xProto Nerd Font, and sets it as Windows Terminal's default font |

## Install from scratch

1. Windows, admin PowerShell: `powershell -ExecutionPolicy Bypass -File \\wsl$\cachyos\home\<user>\.local\share\chezmoi\wsl\windows-setup.ps1`
2. WSL: `sudo cp ~/.local/share/chezmoi/wsl/wsl.conf /etc/wsl.conf`
3. One time only, for a new empty data disk (destroys its contents): in admin PowerShell
   `wsl --mount \\.\PHYSICALDRIVE<n> --bare`, then in WSL find it by size and model with `lsblk -o NAME,SIZE,MODEL`,
   create one GPT partition of type Linux named `data` (`sfdisk`), and `sudo mkfs.ext4 -L data -O ^orphan_file <partition>`.
   Then `wsl --unmount \\.\PHYSICALDRIVE<n>`.
4. `wsl --shutdown`, reopen, then in WSL: `sudo ln -s /mnt/wsl/data /data`, `sudo chown $USER: /mnt/wsl/data`,
   and `chezmoi apply` (runs `data-links install`).

## Uninstall

1. WSL: `data-links uninstall` (moves toolchains back to `$HOME`), then `sudo rm /data`.
2. WSL: remove the `command = ...schtasks.exe...` line from `/etc/wsl.conf`.
3. Windows, admin PowerShell: `windows-setup.ps1 -Uninstall`, then `wsl --shutdown`.

## Why it is built this way

- `wsl --mount` does not persist and needs admin. A non-admin process may start an existing task that runs with
  highest privileges, so both Windows logon and the WSL boot command start the same task.
- WSL splits the `[boot] command` on spaces and ignores quotes, so the task name has no spaces.
- The Start-menu CachyOS entry opens in Windows Terminal with its default settings, not the `cachyos` profile,
  so the font is set in `profiles.defaults`.
