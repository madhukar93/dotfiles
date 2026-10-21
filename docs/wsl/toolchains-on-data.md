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

Folders: mise data and cache, rustup, cargo, go, gem, uv, pipx, npm cache, uv cache, and `~/code`.

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

## Homebrew stays where it is

Homebrew (about 3 GB at `/home/linuxbrew/.linuxbrew`) was not moved. Its ready-built packages only work at
that exact path; a symlink would make Homebrew build from source. Moving it would need a bind mount set up at
boot. Not worth it.

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
| `mise doctor` complains | Run it and read the first warning | Usually a missing `mise activate` in a shell config |
