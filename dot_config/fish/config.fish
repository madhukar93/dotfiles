function fish_user_key_bindings
    # from `help editor`
    # Execute this once per mode that emacs bindings should be used in
    fish_default_key_bindings -M insert

    # Then execute the vi-bindings so they take precedence when there's a conflict.
    # Without --no-erase fish_vi_key_bindings will default to resetting all bindings.
    # The argument specifies the initial mode (insert, "default" or visual).
    fish_vi_key_bindings --no-erase insert
    #     bind --mode insert . _puffer_fish_expand_dot
    #     bind --mode insert ! _puffer_fish_expand_bang
    #     bind --mode insert '$' _puffer_fish_expand_lastarg
    bind -M default \cf accept-autosuggestion
    bind -M insert \cf accept-autosuggestion
end

fish_user_key_bindings

eval "$(/opt/homebrew/bin/brew shellenv)"

direnv hook fish | source
set -gx EDITOR nvim

set -gx fish_tmux_autoquit false
set -gx GPG_TTY (tty)

set -gx FZF_DEFAULT_COMMAND "fd -a . (pwd)"

set -gx GEM_HOME "$HOME/.gem"
set -gx GEM_PATH "$HOME/.gem"

function tigf
    tig (fzf)
end

abbr -a tf terraform

# kubectl aliases
alias k kubectl
abbr -a kd 'k describe'
abbr -a kg 'k get'
abbr -a kaf 'k apply -f'
abbr -a L --position anywhere --set-cursor "% | less"

abbr -a ls lsd
abbr -a l ls -l
abbr -a la ls -a
abbr -a ll 'ls -la'
abbr -a lt 'ls --tree'

# source (kubebuilder completion fish | psub)
source "$(brew --prefix)/share/google-cloud-sdk/path.fish.inc"

fish_add_path -g "$HOME/.local/bin"

alias bw='NODE_OPTIONS="--no-deprecation" command bw'

# Replaced by mise
# set -gx PYENV_ROOT $HOME/.pyenv
# set -gx PATH $PYENV_ROOT/bin $PATH
# status is-interactive; and pyenv init - | source
# status is-interactive; and pyenv virtualenv-init - | source

# starship init fish | source

source "$HOME/.config/fish/shell_integration.fish"

alias nnn='command nnn -a'

set -gx EGET_BIN '$HOME/.local/bin'

set -gx NNN_PLUG 'z:autojump;P:preview-tui;f:fzplug;y:cbcopy-mac;p:cbpaste-mac;e:-!sudo -E vim "$nnn"*'
set -gx NNN_FIFO "/tmp/nnn.fifo"
set -gx NODE_OPTIONS --no-deprecation

# Added by `rbenv init` on Wed Oct 23 23:13:22 IST 2024
# Replaced by mise
# status --is-interactive; and rbenv init - --no-rehash fish | source

fish_add_path -g "$HOME/.pub-cache/bin"
alias tailscale /Applications/Tailscale.app/Contents/MacOS/Tailscale

# Light/dark theme for the programs running inside the terminal.
# The terminal itself already follows the system appearance via
# ~/.config/ghostty/config. theme-sync points glow, fzf, lsd, k9s and atuin
# at colours suited to the current background. See `functions/theme-sync.fish`.
theme-sync

# Re-check before each command, so a shell opened this morning is still correct
# after the system flips to dark this evening. `path mtime` is a fish builtin,
# so this costs a stat and no subprocess.
function __theme_check --on-event fish_preexec --description 'Resync the theme if the system appearance changed'
    set -l m (path mtime $HOME/Library/Preferences/.GlobalPreferences.plist 2>/dev/null)
    if test "$m" != "$__theme_prefs_mtime"
        theme-sync
    end
end

# https://github.com/sharkdp/bat/issues/1746#issuecomment-1004698823
set -gx BAT_THEME ansi
set -gx KUBECTL_EXTERNAL_DIFF "dyff between --omit-header --set-exit-code"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# Enable AWS CLI autocompletion
complete --command aws --no-files --arguments '(begin; set --local --export COMP_SHELL fish; set --local --export COMP_LINE (commandline); aws_completer | sed \'s/ $//\'; end)'

# If you need to have mysql-client first in your PATH, run:
fish_add_path /opt/homebrew/opt/mysql-client/bin

# For compilers to find mysql-client you may need to set:
set -gx LDFLAGS -L/opt/homebrew/opt/mysql-client/lib
set -gx CPPFLAGS -I/opt/homebrew/opt/mysql-client/include

# For pkgconf to find mysql-client you may need to set:
set -gx PKG_CONFIG_PATH /opt/homebrew/opt/mysql-client/lib/pkgconfig

if status is-interactive
    # Add this line to initialize Atuin
    atuin init fish | source
    mise activate fish | source
end

function claude-personal
    env \
        CLAUDE_CONFIG_DIR="$HOME/.claude-personal" \
        claude $argv
end

set -gx CLAUDE_CODE_WORKFLOWS 1

function cdwt --description 'Fuzzy search and cd into a git worktree'
    set -l target (git worktree list | fzf | string split -m 1 ' ')[1]
    if test -n "$target"
        cd $target
    end
end

# >>> grok installer >>>
fish_add_path $HOME/.grok/bin
# <<< grok installer <<<
