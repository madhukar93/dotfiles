# systemd user session and WSLg

## Starting point

The CachyOS WSL image enables systemd but masks `user@.service` (the per-user systemd instance). Its notes
(`docs/systemd-user-sessions-wslg.md` in `madhukar93/cachyos-wsl`) explain why: with a user session, systemd
creates `/run/user/1000` as a fresh tmpfs, which may hide WSLg's sockets, and WSLg expects its own runtime
folder at `/mnt/wslg/runtime-dir`. The image's answer is shell variables pointing `XDG_RUNTIME_DIR` at
`/mnt/wslg/runtime-dir`, at the price of no `systemctl --user`, no user timers or services.

## What was done

`user@.service` was unmasked, then the distro restarted (`wsl --terminate`). Observed after restart:

- `systemctl --user is-system-running` → `running`.
- `/run/user/1000` contains the session files **and** symlinks `wayland-0` and `wayland-0.lock` into
  `/mnt/wslg/runtime-dir`. WSL creates these itself.
- `~/.config/fish/conf.d/wsl.fish` (copied from `/etc/skel`) still forced `XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir`,
  so `systemctl --user` failed in shells ("Failed to connect to user scope bus"). The fix: when
  `/run/user/<uid>/bus` exists, use `/run/user/<uid>`. A test connected to the Wayland socket through that path.
- This file is now managed by chezmoi (`dot_config/fish/conf.d/wsl.fish`, Linux only).

## Alternatives

| Option | Verdict |
|---|---|
| Keep the image's default (masked, shell variables) | Safe but no user services; UWSM-based desktops need a user session |
| Create the Wayland symlink with a user tmpfiles file | Tried and removed: WSL already creates it |
| Always force `/mnt/wslg/runtime-dir` (the image default) | Kept only when no user session bus exists |

## Troubleshooting

- `systemctl --user` fails: `echo $XDG_RUNTIME_DIR`; it must be `/run/user/1000`. Then
  `ls /run/user/1000/bus`.
- GUI apps fail after a change: `ls -l /run/user/1000/wayland-0`. To undo everything: `sudo systemctl mask
  user@.service`, restore `~/.config/fish/conf.d/wsl.fish` from `/etc/skel`, `wsl --terminate`.
- `systemctl is-system-running` says `degraded`: `systemctl --failed`. Here the only failure was
  `systemd-binfmt.service` (WSL mounts `binfmt_misc` read-only; harmless, WSL handles Windows programs itself).
