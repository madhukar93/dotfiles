function glow --description 'glow, with its style matched to the current light/dark theme'
    theme-sync

    # Respect an explicit style if one was given on the command line.
    for a in $argv
        if test "$a" = -s; or string match -q -- '--style*' $a
            command glow $argv
            return $status
        end
    end

    command glow --style $__theme_applied $argv
end
