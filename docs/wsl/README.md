# CachyOS on WSL: design notes and troubleshooting

Written 2026-10-21. These notes explain why the WSL setup looks the way it does, what was tried and
dropped, and how each problem was diagnosed. The install and uninstall steps are in `../../wsl/README.md`.

| Note | Read it when |
|---|---|
| [troubleshooting-method.md](troubleshooting-method.md) | Something does not work and you do not know where to start |
| [data-disk.md](data-disk.md) | `/data` is missing, or you want to know why it is mounted the way it is |
| [toolchains-on-data.md](toolchains-on-data.md) | Moving package folders, mise, `data-links`, or "why not move all of `~`" |
| [gui-on-wsl.md](gui-on-wsl.md) | Hyprland, niri, remote desktop, or how to run Linux GUI apps |
| [systemd-user-session.md](systemd-user-session.md) | `systemctl --user` fails, or `XDG_RUNTIME_DIR` looks wrong |
| [fonts-and-icons.md](fonts-and-icons.md) | Icons show as `�` or empty boxes in Windows Terminal |
| [tmux-theme.md](tmux-theme.md) | The tmux status bar has no theme |
| [vscodium-flatpak.md](vscodium-flatpak.md) | VSCodium does not start, or its startup messages look alarming |
| [chezmoi-and-brew-notes.md](chezmoi-and-brew-notes.md) | chezmoi prompts fail, terraform will not install, push is rejected, Claude settings wiped |

## How these notes were written

By Claude Code at the end of the 2026-10-21 session, from the commands, outputs, logs and user messages
visible in that session. Not copied from a transcript file. Statements marked "inferred", "not verified" or
"not isolated" are reasoning, not proof. Alternatives marked "not tried" came from research or discussion
only. Re-check before relying on them.
