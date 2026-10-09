function theme-sync --description 'Point terminal programs at light or dark colours'
    set -l force 0
    set -l want

    for a in $argv
        switch $a
            case --force
                set force 1
            case light dark
                set want $a
            case '*'
                echo "theme-sync: unknown argument '$a' (expected light, dark, or --force)" >&2
                return 1
        end
    end

    # Fast path. Reading the system appearance costs about 11 ms, which is too
    # much to pay on every `lsd`. macOS touches this file when the appearance
    # changes, and `path mtime` is a fish builtin, so checking it is free.
    # Skipped when a mode was named outright, which must always be honoured.
    set -l mtime (path mtime $HOME/Library/Preferences/.GlobalPreferences.plist 2>/dev/null)
    if test $force -eq 0; and test -z "$want"; and test -n "$__theme_applied"
        and test "$mtime" = "$__theme_prefs_mtime"
        return 0
    end

    set -l mode (theme-current $want)
    or return 1

    set -g __theme_prefs_mtime $mtime

    if test $force -eq 0; and test "$mode" = "$__theme_applied"
        return 0
    end
    set -g __theme_applied $mode

    # ---------------------------------------------------------------------
    # Environment variables. Each tool reads these when it starts.
    # ---------------------------------------------------------------------

    # glow. Its config file says style "auto", but auto works by asking the
    # terminal for its background colour and falls back to dark when nothing
    # answers. Setting the style outright removes that dependency.
    set -gx GLAMOUR_STYLE $mode

    # fzf. Same options _fzf_wrapper.fish used to supply when nothing was set,
    # kept verbatim, with the light/dark colour base appended.
    set -gx FZF_DEFAULT_OPTS "--cycle --layout=reverse --border --height=90% --preview-window=wrap --marker=\"*\" --color=$mode"

    # Nothing is set for bat, htop, tig, lazygit or nnn on purpose: they draw
    # with the terminal's 16 ANSI colours, which Ghostty already repaints when
    # the system appearance changes.

    # ---------------------------------------------------------------------
    # Config files. Each tool reads these when it starts.
    # ---------------------------------------------------------------------

    set -l k9s_skins "$HOME/Library/Application Support/k9s/skins"
    if test -f "$k9s_skins/$mode.yaml"
        ln -sfn "$k9s_skins/$mode.yaml" "$k9s_skins/current.yaml"
    end

    set -l lsd_dir "$HOME/.config/lsd"
    if test -f "$lsd_dir/colors-$mode.yaml"
        ln -sfn "$lsd_dir/colors-$mode.yaml" "$lsd_dir/colors.yaml"
    end

    set -l alacritty_theme "$HOME/.config/alacritty/catppuccin/catppuccin-latte.toml"
    if test $mode = dark
        set alacritty_theme "$HOME/.config/alacritty/catppuccin/catppuccin-mocha.toml"
    end
    if test -f "$alacritty_theme"
        ln -sfn "$alacritty_theme" "$HOME/.config/alacritty/active.toml"
    end

    __theme_sync_atuin $mode

    return 0
end
