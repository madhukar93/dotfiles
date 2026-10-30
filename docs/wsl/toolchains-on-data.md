# Toolchains and package folders on /data

Goal: every language, package cache and project folder lives on the large `/data` disk, while every tool still
finds it at the usual path under `$HOME`. The whole setup is in the dotfiles, so it can be installed or removed.

## Rule: developer tools come from mise

Languages (Node, Python, Go, Rust, Ruby, Java) and their helpers (uv, pipx) are installed by
[mise](https://mise.jdx.dev), not by Homebrew, pacman, pyenv, rbenv, nvm, sdkman or a standalone rustup.
Reasons: one tool and one config file (`~/.config/mise/config.toml`) shared with the Mac; versions can be pinned
per project; nothing else needs to manage the same runtime.

Left alone on purpose: Homebrew's own Python and Node (awscli, bitwarden-cli and gnupg depend on them) and the
system Python from CachyOS. `brew missing` reports no broken dependencies after the removals.

## How the move works: `data-links`

`~/.local/bin/data-links` holds one list of folders and has three commands:

- `install`: for each folder, copy it to `/data`, check it, delete the original, leave a symlink. A folder that
  does not exist yet is created on `/data`, so its first install lands there.
- `uninstall`: reverse it.
- `status`: show where each folder is.

`run_onchange_after_20-data-links.sh.tmpl` runs `install` on `chezmoi apply` when the list changes, skips
machines without `/data`, and fails (so it retries) when `/data` exists but is not mounted.

Folders: mise data and cache, rustup, cargo, go, gem, uv, pipx, npm cache, uv cache, `~/code`, flatpak's
per-app data (`~/.var`, 4.1 GB on 2026-10-23, mostly VSCodium), and Homebrew's download cache
(`~/.cache/Homebrew`, 0.9 GB). Close flatpak apps before `chezmoi apply`
moves `~/.var`.

`move` runs `sync` between the copy and the delete. Without it, a crash right after a move can leave the
original deleted and the copy never written to disk (see data-disk.md, failure 5).

`dot_config/mise/conf.d/paths.toml` puts `~/go/bin` and `~/.gem/bin` on `PATH`, because nothing else did.

## Why symlinks

| Option | Verdict |
|---|---|
| Symbolic links | Chosen. Work across disks, work on folders, tools that hard-code `~/.cargo` still work. |
| Hard links | Impossible: they cannot cross filesystems and Linux forbids them on folders |
| Set each tool's home variable (`MISE_DATA_DIR`, `CARGO_HOME`, `RUSTUP_HOME`, `GOPATH`, ...) | Not evaluated in the session; added here as an obvious alternative. It needs one variable per tool. |
| Bind mounts | Only discussed for Homebrew (below) |
| Move all of `~` to `/data` | Rejected, see below |

## Why not move all of `~`

1. **Startup order.** At WSL start the disk is mounted by a Windows task a few seconds later. A home on `/data`
   would be missing when the first shell and Claude Code start.
2. **Sharing.** A bare-metal install would share `/data`, but some home files only apply to WSL.
3. **Failure mode.** With a small home on the system disk, a missing `/data` breaks only the large folders,
   not the login.

Common practice: a small home on the system disk, large rebuildable folders on the data disk.

## Homebrew: `/data/linuxbrew` bind-mounted at `/home/linuxbrew/.linuxbrew`

Homebrew (3.1 GB on 2026-10-23) lives in `/data/linuxbrew`. A symlink does not work: `brew` resolves its own
path with `pwd -P`, so it would see the prefix as `/mnt/wsl/data/linuxbrew`, and its ready-built packages only
work at `/home/linuxbrew/.linuxbrew`. A bind mount shows the `/data` folder at that exact path, so
`brew --prefix` still prints `/home/linuxbrew/.linuxbrew`.

`run_onchange_before_00-homebrew-on-data.sh.tmpl` sets it up with `sudo`:

- `/etc/systemd/system/home-linuxbrew-.linuxbrew.mount` does the bind mount. The name is fixed by systemd: it
  is the mount path run through `systemd-escape -p`.
- `/etc/systemd/system/homebrew-mount.service` starts at every boot (`WantedBy=multi-user.target`), waits up to
  120 seconds for the disk to be mounted, checking each second, then starts the mount. The mount unit is
  `BindsTo=` the disk's own mount unit, `mnt-wsl-data.mount`, so it is unmounted with the disk.
- From 2026-10-24 to 2026-10-30 the mount unit was `WantedBy=mnt-wsl-data.mount` instead. The same trigger
  started the flatpak Start-menu refresh in only 1 of 4 boots (below): WSL attaches the disk outside systemd,
  and systemd then does not reliably start what the mount unit wants. The script removes that link.
- Until 2026-10-24 a path unit (`home-linuxbrew-.linuxbrew.path`, watching `/mnt/wsl/data/linuxbrew`) started
  the mount. It never fired after a restart: inotify, which path units use, does not report a filesystem being
  mounted over a folder. The script removes it.
- The mount unit has `DefaultDependencies=no`. With the defaults it is part of `local-fs.target`, and the disk
  is only attached after boot.
- The first terminal opens before the disk is attached, so `config.fish` waits up to 15 seconds for
  `/home/linuxbrew/.linuxbrew/bin/brew` when `/data` is a symlink. Without the wait, that shell starts without
  Homebrew's tmux, mise, and the tools mise provides (node).
- It sorts before `run_once_before_00-install-homebrew.sh.tmpl`, so a dual-boot install mounts the shared
  Homebrew instead of installing a second one. The installer also checks for `/home/linuxbrew/.linuxbrew/bin/brew`
  at run time, because templates are rendered before any script runs.
- After copying, it deletes the original only if it matches the copy. The original is hidden under the mount,
  so the script reaches it through a second, non-recursive bind mount of `/home/linuxbrew`.

The first move (2026-10-23) was done by hand in the same steps, because Claude Code's auto mode would not run a
script file as root. Copy, `sync`, metadata compare of all 108,719 entries, then `diff -rq` of every file's
content, then delete. fish, tmux and chezmoi from Homebrew kept running throughout, because the mount went on
top of the original before the original was deleted.

Undo: `sudo systemctl disable homebrew-mount.service`, then
`sudo cp -a /data/linuxbrew /tmp/linuxbrew` (anywhere off the mount), `sudo systemctl stop home-linuxbrew-.linuxbrew.mount`
(close every shell and tmux session that runs Homebrew's fish or tmux first, or the unmount fails as busy),
copy `/tmp/linuxbrew/.` into the now-empty `/home/linuxbrew/.linuxbrew`, and delete the two unit files
(`home-linuxbrew-.linuxbrew.mount`, `homebrew-mount.service`).

## System folders: flatpak's apps and pacman's download cache

`run_onchange_after_25-system-data-links.sh.tmpl` does for root's folders what `data-links` does for `$HOME`,
with `sudo` and one list:

| Folder | On /data | Size on 2026-10-23 |
|---|---|---|
| `/var/lib/flatpak/{app,runtime,repo,appstream,.removed}` (system-wide flatpak apps and runtimes) | `/data/flatpak/...` | 8.2 GB |
| `/var/cache/pacman/pkg` (packages pacman downloaded) | `/data/pacman-pkg` | 1.8 GB |

It moves an existing folder, or links an existing `/data` folder (the dual-boot case). When both exist, the
pacman cache is merged (package files never change, so `cp -n` is safe), a flatpak folder with no apps is set
aside as `/var/lib/flatpak.before-data`, and two flatpak folders that both hold apps are left for a manual merge.

| Option for flatpak | Verdict |
|---|---|
| Symlink `/var/lib/flatpak` | Used until 2026-10-24. `flatpak install` and `flatpak run` work unchanged, but flatpak apps dropped out of the Windows Start menu (below). |
| Symlink each folder inside `/var/lib/flatpak` except `exports` | Chosen. `exports` (the menu entries, 212 KB) stays on the system disk. |
| A second installation (`/etc/flatpak/installations.d/*.conf`) | Works, but every install needs `--installation=<name>`. |
| Bind mount | Not needed: flatpak follows the symlink. |

### Flatpak apps in the Windows Start menu

WSLg builds the Start menu from a fixed list of folders, including `/var/lib/flatpak/exports/share/applications`
and `/usr/local/share/applications`. It checks each folder once, when WSL starts, and skips a folder that does
not exist until the next start (`/mnt/wslg/weston.log`: "doesn't exist, skipping"). On 2026-10-24 it checked at
01:27:55.796 and the disk was attached at 01:27:58, so with all of `/var/lib/flatpak` on `/data`, no flatpak
app was in the Start menu.

- `exports` stays on the system disk, so WSLg finds and watches the folder. Its entries are links into `app/`, so
  at WSL start they point into the unattached disk.
- `flatpak-start-menu.service` starts at every boot (`WantedBy=multi-user.target`), waits up to 120 seconds
  for the disk to be mounted, then deletes and re-creates each entry, so WSLg sees new files and reads them.
  Started by hand on 2026-10-30, WSLg logged "app list entry updated" for all four apps within a second.
- It first used `WantedBy=mnt-wsl-data.mount`. That ran in only 1 of 4 boots from 2026-10-24 to 2026-10-29
  (`journalctl -b <n> -u flatpak-start-menu.service`). WSL attaches the disk outside systemd, and systemd then
  does not reliably start what the mount unit wants. On 2026-10-29 WSLg read the entries at 14:29:31.745,
  the disk was attached at 14:29:32, and the service never ran.
- `/usr/local/share/applications` links to `~/.local/share/applications`, where Gear Lever puts AppImage menu
  entries. WSLg does not read the home folder.

Undo for pacman's cache: `sudo rm /var/cache/pacman/pkg && sudo cp -a /data/pacman-pkg /var/cache/pacman/pkg`,
then delete the `/data` copy once the original path works. For flatpak, do the same for each link inside
`/var/lib/flatpak`, then `sudo systemctl disable flatpak-start-menu.service` and delete its unit file.

pacman was checked after the move with `sudo pacman -Sw pacman-contrib` (download only): the package landed in
`/data/pacman-pkg`.

Programs pacman installs (`/usr`, `/opt`, 5.5 GB) stay on the system disk. They are the operating system,
needed at boot before `/data` is attached, and a dual-boot install has its own.

## Where each tool installs new packages (checked, then fixed)

| Install | Location | On /data? |
|---|---|---|
| `mise use` | `~/.local/share/mise` | yes |
| `npm install -g` | inside mise's Node folder | yes |
| `cargo install` | `~/.cargo/bin` | yes |
| `go install` | mise sets `GOBIN` to its Go folder, so binaries land in `~/.local/share/mise/installs/go/<ver>/bin` | yes (but tied to that Go version) |
| `gem install` | `~/.gem` (`GEM_HOME` set in `config.fish`) | yes |
| `uv tool`, `pipx` | `~/.local/share/uv`, `~/.local/share/pipx`; commands in `~/.local/bin` | yes |

How this was found: `go env`, `npm prefix -g`, `gem env`, `uv tool dir`, `pipx environment`, and `echo $PATH`
in a fresh fish. Do the same after adding a new language.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `node: command not found` right after a restart | `/data` is not mounted, so the symlinked mise folder is a dead link | Mount `/data` (see data-disk.md) |
| `data-links install` says "both it and /data/x exist" | A folder was recreated at the old path | Merge by hand, then run again |
| A tool is installed but not found | Its bin folder is not on `PATH` | Add it in `mise/conf.d/paths.toml` |
| A flatpak app is "not installed" right after a restart | `/data` is not mounted yet | Mount `/data` (see data-disk.md) |
| `brew`, Homebrew's fish or tmux missing after a restart | `/data` is not mounted, or the bind mount did not start | `findmnt /home/linuxbrew/.linuxbrew`; `systemctl status homebrew-mount.service home-linuxbrew-.linuxbrew.mount` |
| pacman says it cannot write to its cache | `/var/cache/pacman/pkg` points to an unmounted `/data` | Mount `/data` |
| `flatpak install` or `update` says "not allowed for user" | System-wide changes go through polkit, and WSL runs no polkit password agent. Not caused by `/data`. | `sudo flatpak ...` |
| `mise doctor` complains | Run it and read the first warning | Usually a missing `mise activate` in a shell config |
