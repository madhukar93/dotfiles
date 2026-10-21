# chezmoi, Homebrew and git notes from the WSL setup

## chezmoi

- **`chezmoi init --prompt` fails with "could not open a new TTY"** when run without a terminal (for example
  through Claude Code's `!` prefix). Give the answer as a flag. The key is the *full prompt text*, not the
  setting name: `chezmoi init --data=false --promptBool "Is this your personal machine=true"`.
- `personal = true` means "this is a personal machine". Answering "no" asks three more work questions and, on the
  next `chezmoi apply`, turns off personal-only files (for example Neovim's AI plugin). The prompt for a yes/no
  question does not echo the typed letters, which looks like nothing was entered.
- `chezmoi apply` also needs a terminal when a file changed outside chezmoi ("has changed since chezmoi last
  wrote it?"); use `--force` after checking `chezmoi diff`.
- Per-OS files use `.chezmoiignore` templates: niri, Noctalia, the flatpak override and `wsl.fish` are Linux
  only; `.chezmoiignore` also lists `wsl/` and `docs/` so they are not copied to `$HOME`.
- `run_onchange_` scripts embed a hash of their input (`{{ include "..." | sha256sum }}`) so they run again
  when the input changes.

## Homebrew

- **A Brewfile is not found by `brew bundle`** unless it is named `Brewfile` in the current folder. Yours is
  `~/.Brewfile`: use `brew bundle --global`.
- **`terraform` no longer exists in Homebrew's core list** (`No available formula with the name "terraform"`).
  The Brewfile now has `tap "hashicorp/tap"` and `brew "hashicorp/tap/terraform"`.
- **Newer Homebrew refuses third-party taps until trusted**: `Refusing to load formula ... from untrusted tap`.
  Trust only the formula you need: `brew trust --formula hashicorp/tap/terraform` (recorded in
  `~/.homebrew/trust.json`; undo with `brew untrust --formula ...`). Narrower than trusting the whole tap.
  Other taps in the macOS part of the Brewfile may need the same on the Mac.
- `tldr` installed but Homebrew warned it is deprecated (disabled upstream). A replacement was not researched.

## git

- **Push rejected ("fast-forward")** after commits were made elsewhere: `git fetch`, list
  `git log HEAD..origin/master` and check whether the files overlap with yours, then `git rebase origin/master`
  and push. Here the Mac's two tmux commits touched different files.
- `gh auth login` and `gh auth setup-git` must run in a real terminal (they ask questions). Without them,
  pushing over HTTPS fails with "could not read Username".
- This repository is public: nothing with account numbers, host names or secrets may be committed. Before a
  large push: `gitleaks git --no-banner --redact .` and `gitleaks dir ...` on new files.

## Bits of WSL knowledge used

- WSL starts Windows programs from Linux (interop, `[interop] enabled = true`) and shows Windows drives under
  `/mnt/c`. That is how the setup edited Windows files and ran `schtasks.exe`. Programs started this way run
  without admin rights. Setting `enabled = false` would also break the `/data` boot command.
- `memory=48GB` in `%USERPROFILE%\.wslconfig` raises WSL's share of RAM from half (about 30 GB of 64) to 48 GB;
  it takes effect after the WSL virtual machine restarts.
