function fish_user_key_bindings
    # from `help editor`
    # Execute this once per mode that emacs bindings should be used in
    fish_default_key_bindings -M insert

    # Then execute the vi-bindings so they take precedence when there's a conflict.
    # Without --no-erase fish_vi_key_bindings will default to
    # resetting all bindings.
    # The argument specifies the initial mode (insert, "default" or visual).
    fish_vi_key_bindings --no-erase insert
    bind -M default \cf accept-autosuggestion
    bind -M insert \cf accept-autosuggestion
end

set -U EDITOR nvim

fish_user_key_bindings

direnv hook fish | source
set -gx EDITOR nvim

set -gx fish_tmux_autoquit false

set -gx GPG_TTY (tty)

alias fdfind fd
set -gx FZF_DEFAULT_COMMAND "fd -a . (pwd)"

function tigf
    tig (fzf)
end

alias k kubectl

# kubectl aliases
abbr -a k kubectl
abbr -a kd 'k describe'
abbr -a kg 'k get'
abbr -a kaf 'k apply -f'
abbr -a kdel 'k delete'
abbr -a ke 'k edit'
abbr -a kccc 'k config current-context'
abbr -a kcdc 'k config delete-context'
abbr -a kcsc 'k config set-context'
abbr -a kcuc 'k config use-context'
abbr -a kdd 'kd deployment'
abbr -a kdeld 'kdel deployment'
abbr -a kdeli 'kdel ingress'
abbr -a kdelp 'kdel pods'
abbr -a kdels 'kdel svc'
abbr -a kdelsec 'kdel secret'
abbr -a kdi 'kd ingress'
abbr -a kdp 'kd pods'
abbr -a kds 'kd svc'
abbr -a kdsec 'kd secret'
abbr -a ked 'ke deployment'
abbr -a kei 'ke ingress'
abbr -a kep 'ke pods'
abbr -a kes 'ke svc'
abbr -a keti 'k exec -ti'
abbr -a kgd 'kg deployment'
abbr -a kgi 'kg ingress'
abbr -a kgp 'kg pods'
abbr -a kgrs 'kg rs'
abbr -a kgs 'kg svc'
abbr -a kgsec 'kg secret'
abbr -a kl 'k logs'
abbr -a klf 'k logs -f'
abbr -a krh 'k rollout history'
abbr -a krsd 'k rollout status deployment'
abbr -a kru 'k rollout undo'
abbr -a ksd 'k scale deployment'

source (kubebuilder completion fish | psub)

# TODO: cleanup, move stuff like this to conf.d/macos.fish, conf.d/linux.fish
switch (uname)
    case Darwin
        source "(brew --prefix)/share/google-cloud-sdk/path.fish.inc"
        # or just check if xclip exists?
        function pbpaste
            xclip -selection clipboard -o
        end

        function pbcopy
            xclip -selection clipboard
        end

end

# TODO: chezmoi init to automatically install brew and other packages

if test -d /home/linuxbrew/.linuxbrew # Linux
    set -gx HOMEBREW_PREFIX "/home/linuxbrew/.linuxbrew"
    set -gx HOMEBREW_CELLAR "$HOMEBREW_PREFIX/Cellar"
    set -gx HOMEBREW_REPOSITORY "$HOMEBREW_PREFIX/Homebrew"
    source /home/linuxbrew/.linuxbrew/opt/asdf/libexec/asdf.fish
else if test -d /opt/homebrew # MacOS
    set -gx HOMEBREW_PREFIX /opt/homebrew
    set -gx HOMEBREW_CELLAR "$HOMEBREW_PREFIX/Cellar"
    set -gx HOMEBREW_REPOSITORY "$HOMEBREW_PREFIX/homebrew"
end
fish_add_path -gP "$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin"
! set -q MANPATH; and set MANPATH ''
set -gx MANPATH "$HOMEBREW_PREFIX/share/man" $MANPATH
! set -q INFOPATH; and set INFOPATH ''
set -gx INFOPATH "$HOMEBREW_PREFIX/share/info" $INFOPATH

# used by a bunch of stuff pipx etc
fish_add_path -g "$HOME/.local/bin/"

set sponge_purge_only_on_exit true
# 130 - sigint <ctr + c>
set sponge_successful_exit_codes 0 127 130

abbr -a tf terraform

nvm use latest --silent

source "$HOME/.cargo/env.fish"

fish_add_path -g "$HOME/go/bin/"

abbr -a mk 'microk8s kubectl'
set -gx KUBECONFIG "$HOME/.kube/config:$HOME/.kube/microk8s"

# Lando
fish_add_path -g "$HOME/.lando/bin"
fish_add_path -g "$HOME/.krew/bin"

status --is-interactive; and . (pyenv init - | psub)

# https://github.com/bitwarden/clients/issues/6689
alias bw='NODE_OPTIONS="--no-deprecation" command bw'

starship init fish | source

# https://github.com/wez/wezterm/issues/115#issuecomment-1902765788
# FIXME: not working on the linux box
source "$HOME/.config/fish/shell_integration.fish"
