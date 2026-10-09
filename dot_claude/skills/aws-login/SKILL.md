---
name: aws-login
description: Restore AWS credentials with the local aws-login-auto command, which signs in to the AWS console in a hidden browser. Use when an aws command fails with ExpiredToken, InvalidClientTokenId, or "Unable to locate credentials"; when work needs an AWS account that has no profile yet; or when deciding which AWS account to act on.
allowed-tools: Bash, Read
---

# Restoring AWS credentials

`aws-login-auto` signs in to the AWS console in a hidden browser using a password
held in the macOS Keychain, and refreshes the named profile's credentials. It takes
15 to 30 seconds and shows no window. Full options: `aws-login-auto --help`.

## Choose the account before signing in

There is deliberately no profile named `default` on this machine, and both login
commands refuse to create one. A bare `aws` command failing with "Unable to locate
credentials" is that design working — name a profile instead of creating a default.

Decide which account in this order:

1. The task or the working directory names it.
2. `aws configure list-profiles` shows what exists.
3. When several exist and nothing indicates which, ask the user.

Sign in to a production account only when the task names it explicitly.

## Restore credentials

```
aws-login-auto --profile <name>
```

The command verifies itself: it asks AWS who it ended up as, checks that the
account matches the one intended, and exits non-zero if either fails. So a zero
exit code means the credentials are real and belong to the right account — no
separate check is needed.

## Create a profile for a new account

```
aws-login-auto --profile <name> --account <12-digit-number> --user <iam-user-name> --region <region>
```

The profile is created in `~/.aws/config` as part of signing in, and both values are
remembered, so later logins need only `--profile`.

## When this needs the user

Exit code 1 with "no password stored ... and there is no terminal to ask on" means
that account's password was never saved to the Keychain. You cannot supply it. Ask
the user to run `aws-login-auto --profile <name>` themselves once in a terminal;
it stores the password and every later login is unattended.

## Diagnosing a failure

`--dry-run` fills the sign-in form and stops without submitting, which separates a
broken tool from a rejected password. If the sign-in page itself has changed,
`~/.local/share/aws-login-auto/README.md` explains how to find the new field names
and repair it.
