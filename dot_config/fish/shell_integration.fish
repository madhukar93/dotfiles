#!/usr/bin/env fish

function terminal_set_user_var
    if command -v base64 >/dev/null
        if test -z "$TMUX"
            printf "\033]1337;SetUserVar=%s=%s\007" "$argv[1]" (echo -n "$argv[2]" | base64)
        else
            # Make sure "set -g allow-passthrough on" is in your tmux.conf
            printf "\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\" "$argv[1]" (echo -n "$argv[2]" | base64)
        end
    end
end

if begin
        status --is-interactive; and not functions -q -- terminal_status; and test "$TERM" != screen; and test "$TERM" != screen-256color; and test "$TERM" != tmux-256color; and test "$TERM" != dumb; and test "$TERM" != linux
    end
    function terminal_status
        printf "\033]133;D;%s\007" $argv
    end

    # Mark start of prompt
    function terminal_prompt_mark
        printf "\033]133;A\007"
    end

    # Mark end of prompt
    function terminal_prompt_end
        printf "\033]133;B\007"
    end

    # Tell terminal to create a mark at this location
    function terminal_preexec --on-event fish_preexec
        printf "\033]133;C;\007"
    end

    function terminal_write_remotehost_currentdir_uservars
        if not set -q -g terminal_hostname
            printf "\033]1337;RemoteHost=%s@%s\007\033]1337;CurrentDir=%s\007" \
                (printf "%s" "$USER@(hostname -f 2>/dev/null)" | base64) \
                (printf "%s" "$PWD" | base64)
        else
            printf "\033]1337;RemoteHost=%s@%s\007\033]1337;CurrentDir=%s\007" \
                (printf "%s" "$USER@$terminal_hostname" | base64) \
                (printf "%s" "$PWD" | base64)
        end

        # Users can define a function called terminal_print_user_vars.
        # It should call terminal_set_user_var and produce no other output.
        if functions -q -- terminal_print_user_vars
            terminal_print_user_vars
        end
    end

    functions -c fish_prompt terminal_fish_prompt

    function terminal_common_prompt
        set -l last_status $status

        terminal_status $last_status
        terminal_write_remotehost_currentdir_uservars
        if not functions terminal_fish_prompt | string match -q "*terminal_prompt_mark*"
            terminal_prompt_mark
        end
        return $last_status
    end

    function terminal_check_function -d "Check if function is defined and non-empty"
        test (functions $argv[1] | grep -cvE '^ *(#|function |end$|$)') != 0
    end

    if terminal_check_function fish_mode_prompt
        # Only override fish_mode_prompt if it is non-empty.
        functions -c fish_mode_prompt terminal_fish_mode_prompt
        function fish_mode_prompt --description 'Write out the mode prompt; do not replace this. Instead, change fish_mode_prompt before sourcing this script, or modify terminal_fish_mode_prompt instead.'
            terminal_common_prompt
            terminal_fish_mode_prompt
        end

        function fish_prompt --description 'Write out the prompt; do not replace this. Instead, change fish_prompt before sourcing this script, or modify terminal_fish_prompt instead.'
            # Remove the trailing newline from the original prompt.
            printf "%b" (string join "\n" (terminal_fish_prompt))

            terminal_prompt_end
        end
    else
        # fish_mode_prompt is empty or unset.
        function fish_prompt --description 'Write out the mode prompt; do not replace this. Instead, change fish_prompt before sourcing this script, or modify terminal_fish_mode_prompt instead.'
            terminal_common_prompt

            # Remove the trailing newline from the original prompt.
            printf "%b" (string join "\n" (terminal_fish_prompt))

            terminal_prompt_end
        end
    end

    terminal_write_remotehost_currentdir_uservars
end
