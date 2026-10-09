function __theme_sync_atuin --description 'Write the theme name into atuin config.toml'
    set -l mode $argv[1]
    set -l cfg "$HOME/.config/atuin/config.toml"

    test -f "$cfg"; or return 0
    test -f "$HOME/.config/atuin/themes/$mode.toml"; or return 0

    # atuin has no environment variable for the theme, so the name has to live
    # in its config file. Only the managed block below is rewritten; the rest
    # of the file is left exactly as it was.
    set -l tmp (mktemp)

    # Remove every previous managed block (marker line plus the two after it),
    # then drop any trailing blank lines so the file cannot grow on each switch.
    # Written in awk because BSD sed has no '+N' address range.
    awk '
        /^# managed by theme-sync/ { skip = 3 }
        skip > 0                   { skip--; next }
                                   { lines[++n] = $0 }
        END {
            while (n > 0 && lines[n] == "") n--
            for (i = 1; i <= n; i++) print lines[i]
        }
    ' "$cfg" >$tmp

    printf '\n# managed by theme-sync - do not edit by hand\n[theme]\nname = "%s"\n' $mode >>$tmp
    mv -f $tmp "$cfg"
end
