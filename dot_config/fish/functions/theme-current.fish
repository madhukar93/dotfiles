function theme-current --description 'Print light or dark, matching the system appearance (macOS, Windows via WSL, or the Linux desktop setting)'
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
    if command -q defaults
        set -l style (defaults read -g AppleInterfaceStyle 2>/dev/null)
        if test "$style" = Dark
            echo dark
        else
            echo light
        end
        return 0
    end

    # WSL: Windows stores AppsUseLightTheme as 0x0 in dark mode and 0x1 in
    # light mode. reg.exe answers in about 30 ms.
    if command -q reg.exe
        if reg.exe query 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' /v AppsUseLightTheme 2>/dev/null | string match -q '*0x0*'
            echo dark
            return 0
        end
    end

    # Linux desktop: the freedesktop appearance setting that apps (and kitty) follow.
    # The portal answers "v v u N": 1 = dark, 2 = light, 0 = no preference.
    if command -q busctl
        set -l scheme (busctl --user call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.Settings Read ss org.freedesktop.appearance color-scheme 2>/dev/null | string match -r '\d+$')
        switch "$scheme"
            case 1
                echo dark
                return 0
            case 2
                echo light
                return 0
        end
    end

    # No signal available: default to light.
    echo light
end
