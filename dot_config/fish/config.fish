function fish_user_key_bindings
    # from `help editor`
    # Execute this once per mode that emacs bindings should be used in
    fish_default_key_bindings -M insert

    # Then execute the vi-bindings so they take precedence when there's a conflict.
    # Without --no-erase fish_vi_key_bindings will default to resetting all bindings.
    # The argument specifies the initial mode (insert, "default" or visual).
    fish_vi_key_bindings --no-erase insert
    bind --mode insert . _puffer_fish_expand_dots
    bind --mode insert ! _puffer_fish_expand_bang
    bind --mode insert '$' _puffer_fish_expand_lastarg
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

set -gx PYENV_ROOT $HOME/.pyenv
set -gx PATH $PYENV_ROOT/bin $PATH
status is-interactive; and pyenv init - | source
status is-interactive; and pyenv virtualenv-init - | source

starship init fish | source

source "$HOME/.config/fish/shell_integration.fish"

alias nnn='command nnn -a'

set -gx EGET_BIN '$HOME/.local/bin'

set -gx NNN_PLUG 'z:autojump;P:preview-tui;f:fzplug;y:cbcopy-mac;p:cbpaste-mac;e:-!sudo -E vim "$nnn"*'
set -gx NNN_FIFO "/tmp/nnn.fifo"
set -gx NODE_OPTIONS --no-deprecation

# Added by `rbenv init` on Wed Oct 23 23:13:22 IST 2024
status --is-interactive; and rbenv init - --no-rehash fish | source

fish_add_path -g "$HOME/.pub-cache/bin"
alias tailscale /Applications/Tailscale.app/Contents/MacOS/Tailscale

set k9s_skin_dir (k9s info | grep 'k9s/skins' | cut -d' ' -f2- | string trim)
set k9s_current_theme $k9s_skin_dir/current.yaml

if test "$ALACRITTY" = true
    function theme
        ln -sf $HOME/.config/alacritty/{$argv[1]}.toml $HOME/.config/alacritty/active.toml
    end

    function theme_k9s
        ln -sf $k9s_skin_dir/{$argv[1]}.yaml $k9s_current_theme
    end

    set -l ALACRITTY_THEME (defaults read -g AppleInterfaceStyle 2>/dev/null; or echo "Light")

    if test "$ALACRITTY_THEME" = Dark
        theme catppuccin/catppuccin-mocha
        theme_k9s solarized-dark

    else
        theme catppuccin/catppuccin-latte
        theme_k9s solarized-light
    end
end

# https://github.com/sharkdp/bat/issues/1746#issuecomment-1004698823
set -gx BAT_THEME ansi
set -gx KUBECTL_EXTERNAL_DIFF "dyff between --omit-header --set-exit-code"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :
