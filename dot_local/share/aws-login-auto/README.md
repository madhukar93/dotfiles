# Automatic AWS sign-in for `aws login`

## What is installed

| File | What it is |
|---|---|
| `~/.local/bin/aws-login` | Runs the normal `aws login`, but opens the sign-in page with the account number and IAM user name already filled in. You still type the password. |
| `~/.local/bin/aws-login-browser` | Helper used by the above. Rewrites the sign-in link. Not run directly. |
| `~/.local/bin/aws-login-auto` | Runs the whole sign-in with no typing, using a hidden browser. |
| `~/.local/share/aws-login-auto/aws-login-auto.mjs` | The program behind `aws-login-auto`. |
| `~/.local/share/aws-login-auto/discover.mjs` | Diagnostic. Prints the sign-in page's form structure. Use it if AWS changes the page. |

## Why a rewritten link is needed

`aws login` prints a link ending in `/v1/authorize`. That link leads to a page that
asks which session you want, and it throws away any account number you attach to it.
One step further along is the IAM user sign-in form, at `/oauth`, and that page does
accept two extra values:

- `account` — the 12-digit AWS account number
- `login_hint` — the IAM user name

Both scripts rewrite the first link into the second and attach those values. The
one-time security values in the original link (`state`, `code_challenge`,
`redirect_uri`) are carried across unchanged, which is what lets the sign-in still
return correctly to the waiting `aws login`.

## How a login is confirmed

Neither command trusts `aws login` exiting cleanly. Both then ask AWS directly with
`aws sts get-caller-identity` and check two things: that the profile now produces
usable credentials, and that they belong to the account that was intended. Reaching
the wrong account counts as a failure, not a success - it is worse than reaching none.
A zero exit code therefore means the credentials are real and the account is right.

## What this needs on the machine

- **Google Chrome**, installed in `/Applications`. The automated login drives it in a
  throwaway profile; it does not download a browser of its own.
- **Node**, for `aws-login-auto` itself.
- **The AWS CLI**, version 2.36 or later, which is where the `aws login` command lives.

`aws-login` and `aws-login-browser` need none of these beyond the AWS CLI, which is why
they stay usable when the automated path cannot run.

On a machine set up from the dotfiles repository, chezmoi's
`run_onchange_after_40-install-aws-login-auto.sh` installs the one dependency and warns
if Chrome or Node is missing. Neither Chrome nor Node is in the Brewfile, so install
them yourself.

## Setting up a profile that does not exist yet

Give the account number and user name the first time; both are remembered afterwards.

    aws-login-auto --profile prod --account 111122223333 --user your.name --region eu-west-1

The profile is created in `~/.aws/config` as part of signing in. Two lines end up
there: `login_session`, written by `aws login` itself, and `region`, written by this
script.

The region needs writing because `aws login` only records it when it had to stop and
ask you for one. This script always passes the region on the command line, so it is
never asked, and without this step a new profile would be left with no region and
every later command using that profile would fail.

## Where the password is kept

In the macOS Keychain, under service name `aws-login`, with the item named after the
account number and user name, for example `111122223333:your.name`.

Inspect it:

    security find-generic-password -s aws-login -a '<account>:<user>'

Remove it:

    aws-login-auto --profile <name> --forget

The password is never passed as a command argument, never written to a file, and never
printed. It is given to `security` and to the browser over their standard input.

## Where the password comes from

The script tries three sources in order:

1. A command you name with `--password-command`, or the environment variable
   `AWS_LOGIN_PASSWORD_COMMAND`. The text `{user}`, `{account}` and `{region}` is
   substituted before the command runs, so one setting serves every profile.
   Any password manager with a command line can be plugged in this way.
2. Its own Keychain entry, described in the section above.
3. Asking you, offering to save it for next time.

### The macOS Passwords app does not work as a source

Tested on 22 August 2026 and it does not: entries in the Passwords app are held in
iCloud Keychain, which the `security` command line tool cannot read. Asking it for one
returns "The specified item could not be found in the keychain", even when the entry is
plainly visible in the Passwords app. There is no command line route to those entries.

So if you keep the password in the Passwords app, this script holds a second copy in
its own Keychain entry. If you ever change the AWS password, update both: change it in
the Passwords app as usual, then run `aws-login-auto --profile <name> --forget` and log
in once to store the new one.

## Multi-factor codes

If AWS asks for a multi-factor code, the script looks for a command to produce one:

    aws-login-auto --profile staging --mfa-command "oathtool --totp -b $SECRET"

or the same thing in the environment variable `AWS_LOGIN_MFA_COMMAND`. The command
should print only the code. This path has never been exercised against a real
multi-factor device, so expect to adjust it the first time you use one.

With no such command configured, the script opens a visible browser window and asks
you to finish by hand.

## When AWS changes the sign-in page

The script depends on four things on the page: the fields `#account`, `#username`
and `#password`, and the button `#signin_button`. If sign-in starts failing, check
whether those still exist:

    cd ~/.local/share/aws-login-auto
    node discover.mjs "<a sign-in link printed by aws login>"

That opens the page and prints every input and button it finds. Update the selectors
near the top of `aws-login-auto.mjs` to match.

`aws-login` (the non-automated one) does not depend on any of those, so it keeps
working as a fallback whenever the automation breaks.

## Checking things without signing in

    aws-login-auto --profile staging --dry-run

Does everything except press Sign in, then reports what the form contained. Nothing
is sent to AWS.

## Working with several AWS accounts safely

There is deliberately **no profile named `default`** on this machine, and no
`~/.aws/credentials` file. That means a bare `aws` command fails with "Unable to
locate credentials" rather than quietly acting on whichever account happened to be
the default. Both `aws-login` and `aws-login-auto` refuse to create or use a profile
called `default` for the same reason; set `AWS_LOGIN_ALLOW_DEFAULT=1` to override.

Four fish pieces support this, all in `~/.config/fish`:

| File | What it does |
|---|---|
| `functions/__aws_profile_risk.fish` | Classifies a profile name as `prod`, `elevated`, `normal` or `none`. Elevated is tested first on purpose, so "preprod" is not painted the same red as production. Override the patterns with `AWS_PROFILE_PROD_PATTERN` and `AWS_PROFILE_ELEVATED_PATTERN`. |
| `functions/fish_right_prompt.fish` | Shows the selected account on the right of the prompt, red for production, yellow for uat and staging, cyan otherwise. Shows nothing when no account is selected. |
| `functions/awsp.fish` | Picks the account for this shell, with fzf when given no argument. `awsp uat` sets it directly, `awsp none` clears it. |
| `functions/awswho.fish` | Says which account the shell really resolves to, by asking AWS rather than trusting the variable - so it also tells you when the login has expired. |
| `conf.d/aws_profile_workspace_colour.fish` | Tints the cmux workspace to match: production red, uat and staging amber, ordinary teal, colour cleared when nothing is selected. |

### How the cmux colour knows the account

`AWS_PROFILE` lives inside one shell process and cmux is a separate application, so
the shell has to tell it. Fish fires a handler whenever that variable changes, and the
handler calls `cmux workspace-action --action set-color`, naming its own workspace with
`CMUX_WORKSPACE_ID`, which cmux places in every pane's environment. Because it watches
the variable rather than any particular command, it works however the profile was set.

Two limits: a workspace holding several panes shows whichever pane changed profile
most recently, so keep one account per workspace; and a one-off `aws --profile prod ...`
does not set the variable, so neither the prompt nor the colour reflects it.

### What this does not protect against

Nothing here stops a destructive command - it only makes the current account visible.
Anything scripted bypasses shell-level protection entirely, which is where the worst
mistakes happen. The real protection is on the AWS side: a read-only production profile
for daily use, with writes requiring a separately assumed role.

## Removing all of it

    rm ~/.local/bin/aws-login ~/.local/bin/aws-login-browser ~/.local/bin/aws-login-auto
    rm -rf ~/.local/share/aws-login-auto
    security delete-generic-password -s aws-login

    rm ~/.config/fish/functions/__aws_profile_risk.fish \
       ~/.config/fish/functions/fish_right_prompt.fish \
       ~/.config/fish/functions/awsp.fish \
       ~/.config/fish/functions/awswho.fish \
       ~/.config/fish/conf.d/aws_profile_workspace_colour.fish
