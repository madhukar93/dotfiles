function awswho --description "Ask AWS which account this shell actually resolves to"
    if not set -q AWS_PROFILE; or test -z "$AWS_PROFILE"
        echo "awswho: no AWS account selected in this shell. Pick one with: awsp"
        return 1
    end

    # Asking AWS rather than trusting the variable: this reports what commands
    # would really act on, including when the login has expired.
    set -l identity (aws sts get-caller-identity --output text --query '[Account,Arn]' 2>&1)
    if test $status -ne 0
        echo "awswho: profile '$AWS_PROFILE' is not usable right now." >&2
        echo "        $identity" >&2
        echo "        Log in with: aws-login-auto --profile $AWS_PROFILE" >&2
        return 1
    end

    set -l parts (string split \t -- $identity)

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
    printf ' is account %s, %s\n' $parts[1] $parts[2]
end
