# VSCodium (Flatpak) would not start

**Symptom.** `flatpak run com.vscodium.codium` printed four lines and no window:

```
com.vscodium.codium-wrapper: Setting up NPM packages
com.vscodium.codium-wrapper: Setting up Cargo packages
com.vscodium.codium-wrapper: Setting up Python packages
com.vscodium.codium-wrapper: 'ruby' is not available
```

Those four lines are normal and are not the error.

## How the cause was found

1. **Run it with a timeout and keep the full log**: `timeout 25 flatpak run com.vscodium.codium --verbose > log 2>&1`.
   The real error was further down: `ozone_platform_x11.cc: Missing X server or $DISPLAY` and
   `The platform failed to initialize. Exiting.` So Electron tried X11, not Wayland.
2. **Look at the sandbox permissions**: `flatpak info --show-permissions com.vscodium.codium` →
   `sockets=fallback-x11;wayland`. "fallback-x11" gives X11 only when Wayland is *not* available. Wayland is
   available, so X11 is withheld. The app must use Wayland.
3. **Test the two ways in**, each with a timeout: sharing the X folder (`--filesystem=/mnt/wslg/.X11-unix`)
   still failed; forcing Wayland (`--ozone-platform=wayland`) ran (exit 124 means it was still running).
   A test shell mistake (zsh gave exit 127 for a command held in a variable) was caught by rerunning through
   `bash -c`.
4. **Why did it choose X11 by itself?** Read the app's start script:
   `flatpak run --command=bash com.vscodium.codium -c 'grep -n ozone /app/bin/com.vscodium.codium'`. It passes
   `--ozone-platform=wayland` only if `XDG_SESSION_TYPE` is `wayland` and the Wayland socket exists; otherwise
   `--ozone-platform=x11`. WSL leaves `XDG_SESSION_TYPE` unset.

## Fix

```
flatpak override --user --env=XDG_SESSION_TYPE=wayland com.vscodium.codium
```

Checked inside the sandbox: the variable is `wayland` and `/run/user/1000/wayland-0` is visible. A later launch
with no flags showed the wrapper passing its Wayland-only options and no "Missing X server" error.
**Not verified:** a clean start from the override alone with no other VSCodium running. The user's "it ran now"
came right after test launches that used extra flags, so those, not the override, may have opened the window. The override
file `~/.local/share/flatpak/overrides/com.vscodium.codium` is in the dotfiles (Linux only).
Undo: `flatpak override --user --reset com.vscodium.codium`.

## Alternatives

| Option | Verdict |
|---|---|
| Pass `--ozone-platform=wayland` every time | Works but must be remembered; the wrapper then also passes `x11` ("option defined more than once, using wayland") |
| `ELECTRON_OZONE_PLATFORM_HINT=wayland` | Tried; inconclusive (an instance was already running, so the launch exited 0 without a result) |
| Share the WSLg X11 folder | Did not help |
| Install VSCodium natively (`vscodium-bin` from the AUR) | Reasonable; it would also see mise tools. Not done. |

## The startup messages, explained

- "Setting up NPM/Cargo/Python packages": the wrapper prepares per-user package folders inside the sandbox.
- `'ruby' is not available`: the wrapper looks for Ruby **inside the sandbox**, a separate Linux system with its
  own Node, Cargo and Python but no Ruby. Your mise Ruby lives outside it. Harmless unless you use Ruby tools in
  VSCodium. Options: a native VSCodium, or the terminal profile `flatpak-spawn --host fish`.
- `Most NODE_OPTIONs are not supported in packaged apps`: from `NODE_OPTIONS=--no-deprecation` in `config.fish`;
  Electron ignores it.

## Troubleshooting any Flatpak/Electron app on WSL

1. Run it with a timeout, save the log; search for `display`, `ozone`, `wayland`, `x11`.
2. `flatpak info --show-permissions <app>` to see sockets.
3. Read the app's start script in `/app/bin`.
4. Try a per-run override (`flatpak run --env=... --socket=...`) before saving a permanent one.
5. Several VSCodium windows appearing after tests were extra instances started by the tests; close them.
