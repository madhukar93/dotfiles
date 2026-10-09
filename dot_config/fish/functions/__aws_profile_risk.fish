function __aws_profile_risk --description "Say how risky an AWS profile name looks: prod, elevated, normal or none"
    set -l profile "$argv[1]"

    if test -z "$profile"
        echo none
        return
    end

    # Which names count as which. Override either by setting the matching
    # variable in config.fish if your account naming differs.
    set -l elevated_pattern 'uat|stag|preprod|pre-prod|qa'
    set -l prod_pattern 'prod'
    set -q AWS_PROFILE_ELEVATED_PATTERN; and set elevated_pattern $AWS_PROFILE_ELEVATED_PATTERN
    set -q AWS_PROFILE_PROD_PATTERN; and set prod_pattern $AWS_PROFILE_PROD_PATTERN

    # Elevated is tested first on purpose: "preprod" and "pre-prod" contain the
    # word "prod", and testing the other way round would paint them the same red
    # as production, which would wear out the meaning of red.
    if string match -qri -- "($elevated_pattern)" $profile
        echo elevated
    else if string match -qri -- "($prod_pattern)" $profile
        echo prod
    else
        echo normal
    end
end
