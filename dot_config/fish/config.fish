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

fish_user_key_bindings

direnv hook fish | source
set -gx EDITOR nvim

set -gx fish_tmux_autoquit false

# kubectl aliases
alias k kubectl
alias kd 'k describe'
alias kg 'k get'
alias kaf 'k apply -f'
alias kdel 'k delete'
alias ke 'k edit'
alias kccc 'k config current-context'
alias kcdc 'k config delete-context'
alias kcsc 'k config set-context'
alias kcuc 'k config use-context'
alias kdd 'kd deployment'
alias kdeld 'kdel deployment'
alias kdeli 'kdel ingress'
alias kdelp 'kdel pods'
alias kdels 'kdel svc'
alias kdelsec 'kdel secret'
alias kdi 'kd ingress'
alias kdp 'kd pods'
alias kds 'kd svc'
alias kdsec 'kd secret'
alias ked 'ke deployment'
alias kei 'ke ingress'
alias kep 'ke pods'
alias kes 'ke svc'
alias keti 'k exec -ti'
alias kgd 'kg deployment'
alias kgi 'kg ingress'
alias kgp 'kg pods'
alias kgrs 'kg rs'
alias kgs 'kg svc'
alias kgsec 'kg secret'
alias kl 'k logs'
alias klf 'k logs -f'
alias krh 'k rollout history'
alias krsd 'k rollout status deployment'
alias kru 'k rollout undo'
alias ksd 'k scale deployment'

source (kubebuilder completion fish | psub)
