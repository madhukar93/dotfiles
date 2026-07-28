# dotfiles

Managed with [chezmoi](https://www.chezmoi.io/). Source of truth for shell (zsh + fish), Neovim (LazyVim),
tmux, WezTerm, Zed, Karabiner, and machine bootstrapping (Homebrew + a curated `Brewfile`).

Supports macOS (Apple Silicon and Intel) and Linux, and distinguishes **personal** vs **work** machines for
a handful of files (AI backend, work SSH/Bedrock config, Android SDK tooling) — see
[.chezmoi.toml.tmpl](.chezmoi.toml.tmpl).

## Bootstrapping a new machine

```sh
xcode-select --install    # macOS only, if not already present
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi
chezmoi init --apply madhukar93/dotfiles
```

`chezmoi init` will prompt:

- **Is this your personal machine?** — answer `false` on a work machine. If `false`, it'll also ask for the
  work project path and AWS Bedrock profile/region (used only in `dot_config/zed/private_settings.json.tmpl`
  and never stored in this repo — see below).

`--apply` immediately writes all managed dotfiles and runs, in order:

1. `run_once_before_00-install-homebrew.sh` — installs Homebrew if missing (skips if already present)
2. `run_onchange_after_10-brew-bundle.sh` — runs `brew bundle --file="$HOME/.Brewfile"` against the curated
   [dot_Brewfile.tmpl](dot_Brewfile.tmpl); re-runs automatically on future `chezmoi apply` whenever the
   Brewfile changes
3. `run_once_after_20-install-oh-my-zsh.sh` / `run_once_after_20-install-fisher.sh` — shell framework/plugin
   manager setup
4. `run_once_after_30-install-sdkman.sh` — the one dependency in `.zshrc` with no Homebrew formula

## Manual steps after bootstrapping (can't be scripted)

- **Neovim**: open `nvim` and run `:Lazy sync` to install the actual plugin set and regenerate
  `lazy-lock.json`.
- **Karabiner-Elements**: grant Input Monitoring / Accessibility permissions in System Settings.
- **Atuin** (synced shell history across machines):
  ```sh
  atuin login -u <username> -k <key>   # key comes from wherever you stashed it (e.g. Bitwarden) — see below
  ```

## Personal/work data

Anything machine-specific but not sensitive branches on `.personal`/`.work` inside the templates directly
(e.g. Android SDK tooling, which AI backend `avante.nvim` uses). Anything that would otherwise put an
internal project name, hostname, or AWS profile into this **public** repo is instead sourced from
`.chezmoi.toml.tmpl` prompts, which are answered once per machine and stored only in that machine's local
`~/.config/chezmoi/chezmoi.toml` — never committed here.

## Atuin

[Atuin](https://atuin.sh) replaces the plain zsh/fish history files with a shared, searchable, end-to-end
encrypted history synced across machines. Two separate pieces of "creds":

- **Account login** (username + password) — chosen by you at `atuin register` time, on whichever machine you
  set this up first.
- **Encryption key** — generated locally by atuin (independent of your account password); this is what
  actually decrypts synced history. Get it with `atuin key`. Save it somewhere durable (a password manager)
  the first time — every other machine needs this *same* key via `atuin login -k <key>` to join the same
  encrypted history pool. Losing it means starting a fresh, unrelated encrypted history on any new machine.
