# Tints the cmux workspace to match the AWS account the shell is pointed at.
#
# AWS_PROFILE lives inside a single shell process, and cmux is a separate
# application that cannot see it. So whenever the variable changes, this handler
# pushes the colour to cmux, naming its own workspace with CMUX_WORKSPACE_ID,
# which cmux places in every pane's environment.
#
# Because the handler watches the variable rather than any particular command,
# it fires however the profile was set: the awsp picker, a manual `set -x`, or
# direnv if that is added later.
#
# Limitation worth knowing: a workspace holding several panes shows whichever
# pane changed profile most recently. Keep one account per workspace for the
# colour to stay truthful.

function __aws_profile_workspace_colour --on-variable AWS_PROFILE \
        --description "Tint the cmux workspace by which AWS account is selected"

    # Only meaningful inside a cmux pane, with the cmux command available.
    if not set -q CMUX_WORKSPACE_ID
        return
    end
    if not type -q cmux
        return
    end

    set -l risk none
    if set -q AWS_PROFILE
        set risk (__aws_profile_risk "$AWS_PROFILE")
    end

    switch $risk
        case prod
            cmux workspace-action --action set-color --color Red \
                --workspace $CMUX_WORKSPACE_ID >/dev/null 2>&1
        case elevated
            cmux workspace-action --action set-color --color Amber \
                --workspace $CMUX_WORKSPACE_ID >/dev/null 2>&1
        case normal
            cmux workspace-action --action set-color --color Teal \
                --workspace $CMUX_WORKSPACE_ID >/dev/null 2>&1
        case '*'
            # Selection cleared, so give the workspace its normal colour back.
            cmux workspace-action --action clear-color \
                --workspace $CMUX_WORKSPACE_ID >/dev/null 2>&1
    end
end
