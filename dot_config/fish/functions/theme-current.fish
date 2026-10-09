function theme-current --description 'Print light or dark, matching the macOS appearance'
    # An explicit argument wins. This is what makes the whole theme setup
    # testable without changing the real system appearance.
    if set -q argv[1]
        switch $argv[1]
            case light dark
                echo $argv[1]
                return 0
            case '*'
                echo "theme-current: expected 'light' or 'dark', got '$argv[1]'" >&2
                return 1
        end
    end

    # macOS leaves AppleInterfaceStyle unset in light mode and sets it to
    # "Dark" in dark mode. This is the same signal Ghostty follows, so the
    # terminal and the programs inside it stay in agreement.
    set -l style (defaults read -g AppleInterfaceStyle 2>/dev/null)
    if test "$style" = Dark
        echo dark
    else
        echo light
    end
end
