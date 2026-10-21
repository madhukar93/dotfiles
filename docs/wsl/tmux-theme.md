# tmux: catppuccin theme did not load

**Symptom.** After `chezmoi apply` brought the Mac's tmux config to WSL, the status bar had no catppuccin
theme. It worked on the other machines.

## Diagnosis

1. `tmux show-messages` showed the config running; no error.
2. tpm's own log (`~/.tmux/plugins/tpm_log.txt`) showed: `Installing "tmux"` then `"tmux" download fail`.
   The other ten entries (including tpm itself) were "Already installed"; only the catppuccin entry was being downloaded, under the name `tmux`.
3. oh-my-tmux (the framework behind `~/.tmux.conf`) finds plugins by loading your config in a throwaway tmux and
   reading what tmux prints for each `set -g @plugin`. Reproducing that: tmux 3.8 prints
   `set-option -g @plugin "catppuccin/tmux#v2.3.1"` with **quotes**, because the value contains `#`. The
   framework kept the quotes, so tpm tried to clone `"catppuccin/tmux`. Entries without `#` print unquoted.

Why it works elsewhere is **not established**. Likely: the plugin folder was already installed there before the
version pin was added (tpm skips existing folders), or those machines run an older tmux that does not quote.

## Fix

- `.chezmoiexternal.toml`: chezmoi downloads the pinned release v2.3.1 into
  `~/.config/tmux/plugins/catppuccin/tmux`.
- `dot_tmux.conf.local`: the `@plugin catppuccin/tmux#v2.3.1` line was removed; after the catppuccin options a
  `run ~/.config/tmux/plugins/catppuccin/tmux/catppuccin.tmux` line loads it (catppuccin's README documents this
  manual install).
- Applied to the running tmux with `tmux source-file ~/.tmux.conf` (no panes closed). Verified with
  `tmux show -gv @catppuccin_flavor` and `tmux display -p '#{E:status-left}'`.

## Alternatives

| Option | Why not |
|---|---|
| Drop the version pin | The pin stops unattended updates from changing the look |
| Hand-install into `~/.tmux/plugins` | Not reproducible; chezmoi external is |
| Patch oh-my-tmux's discovery | It is vendored upstream; edits belong in `.tmux.conf.local` |

## Troubleshooting a plugin that does not load

1. Read the plugin manager's log, not tmux's message list.
2. Does the folder exist under `~/.tmux/plugins`?
3. Print what the framework sees: `tmux -L probe -f /dev/null start-server \; source -nvq ~/.tmux.conf.local | grep @plugin`.
4. Test tmux with a throwaway server (`tmux -L cfgtest ...`) so your sessions stay untouched.

The k8s pill (`~/.local/bin/tmux-kube-pill`) prints nothing when no Kubernetes context is selected; that is
by design, not a failure.
