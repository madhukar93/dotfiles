function awsp --description "Choose which AWS account this shell uses"
    set -l profiles (aws configure list-profiles 2>/dev/null | sort)

    if test (count $profiles) -eq 0
        echo "awsp: no AWS profiles configured yet. Create one with:" >&2
        echo "      aws-login-auto --profile <name> --account <id> --user <iam-user>" >&2
        return 1
    end

    set -l chosen
    if test (count $argv) -gt 0
        # "none" is always accepted, and means clear the selection.
        if test "$argv[1]" = none
            set chosen none
        else if contains -- $argv[1] $profiles
            set chosen $argv[1]
        else
            echo "awsp: no profile named '$argv[1]'. Available: $profiles" >&2
            return 1
        end
    else
        set chosen (printf '%s\n' none $profiles | fzf --prompt="AWS account> " \
            --height=40% --reverse --header="choose 'none' to clear the selection")
    end

    # Empty means the picker was cancelled; leave things as they were.
    if test -z "$chosen"
        return 1
    end

    if test "$chosen" = none
        set -e AWS_PROFILE
        echo "awsp: no AWS account selected in this shell."
        return 0
    end

    set -gx AWS_PROFILE $chosen
    awswho
end
