function fish_right_prompt --description "Show which AWS account this shell is pointed at"
    # Nothing is shown when no account is selected, so the prompt stays quiet
    # until there is something worth warning about.
    if not set -q AWS_PROFILE
        return
    end
    if test -z "$AWS_PROFILE"
        return
    end

    switch (__aws_profile_risk $AWS_PROFILE)
        case prod
            set_color -o brred
        case elevated
            set_color yellow
        case '*'
            set_color cyan
    end

    printf '%s' $AWS_PROFILE
    set_color normal
end
