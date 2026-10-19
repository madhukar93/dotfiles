# Mark shell prompts with OSC 133 escape sequences so tmux's previous-prompt /
# next-prompt commands (bound to Ctrl+Shift+Up / Down in ~/.tmux.conf.local)
# can jump between shell prompts in copy-mode.
#
# Only active inside tmux. Takes effect in new fish sessions, so existing panes
# need a fresh shell (or `exec fish`) before prompt-jump will find their prompts.

if set -q TMUX
    # OSC 133;A -> start of a prompt
    function __tmux_osc133_prompt --on-event fish_prompt
        printf '\x1b]133;A\a'
    end
    # OSC 133;C -> start of command output (lets previous-prompt -o work too)
    function __tmux_osc133_preexec --on-event fish_preexec
        printf '\x1b]133;C\a'
    end
end
