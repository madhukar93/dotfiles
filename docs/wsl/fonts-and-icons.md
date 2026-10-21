# Icons show as `�` in Windows Terminal

**Symptom.** In the tmux status bar the rounded edges of the pills drew correctly, but each icon inside a pill
(terminal, person, server) showed as `�`. The same config looked right on the Mac.

## How it was diagnosed (stage by stage)

The path is: tmux config → tmux output → Windows Terminal → font → screen.

| Stage tested | How | Result |
|---|---|---|
| Does tmux send the right characters? | Attached a read-only client under `script`, counted codepoints in the raw output | U+E795, U+F1AE, U+F048B present (3 each); U+FFFD (the `�` itself) 0 times. tmux is fine. |
| Does the font contain them? | `fc-query -f '%{charset}'` and `pango-view` rendering from the font file | All present; they drew correctly (terminal box, person, server stack) |
| Is it tmux at all? | In a plain tab (no tmux): `printf 'icons:   \U000f048b \n'` | Same `�`, so tmux is not involved |
| Did Windows Terminal ever load the font? | Compared `Get-Process WindowsTerminal`'s StartTime with the time the font was installed | The process pre-dated the install; Windows Terminal reads fonts only when it starts |

Why `�` rather than an empty box: the terminal falls back to its default font and shows the "replacement
character" when no font in the chain has the symbol.

## The fixes, in order

1. **Install a Nerd Font on Windows.** Nerd Fonts (not Font Awesome) carry the icon set catppuccin uses.
   Windows Terminal draws with Windows fonts, so the Nerd Font already installed inside Linux does not help.
   Installed 0xProto Nerd Font (the Mac's font) for the current user only.
2. **Restart Windows Terminal fully** (`Stop-Process -Name WindowsTerminal` from a PowerShell outside it).
   Closing one window is not enough while another is open.
3. **Install for all users** (admin). A forum report describes Windows Terminal not finding a per-user font.
   Not proven to be the cause here.
4. **Set the font in `profiles.defaults`, not only the `cachyos` profile.** A process trace showed `wsl.exe`
   started by `explorer.exe`, so the window was opened from the Start menu. A Start-menu window is likely to use
   Windows Terminal's defaults rather than the `cachyos` profile (not verified in Microsoft's documentation).

**What is proven and what is not.** After steps 3 and 4 plus a full Windows Terminal restart the icons rendered.
The user said "I don't think that worked" after step 3 and again after step 4, then reported success;
the report may have come after the restart finished loading. **Which of the three changes (all-users install,
defaults entry, restart) fixed it was not isolated.** All three are kept because each is harmless.

## Alternatives not taken

- Setting the Nerd Font only in the `cachyos` profile (tried first; it was never used by Start-menu windows).
- Switching catppuccin to plain-text icons (loses the look the Mac has).
- Using another terminal on Windows (WezTerm and Ghostty already use the same font on the Mac; not needed).

## Reproduce / fix on a new machine

`wsl/windows-setup.ps1` (admin PowerShell) installs the font for all users and sets it in Windows Terminal's
defaults. Then restart Windows Terminal.

## Checklist for the next icon problem

1. Print the characters in a plain shell with `printf ''`. Works → the problem is above the terminal.
2. Check `Get-Process WindowsTerminal | Select StartTime`; restart if older than the font change.
3. Check which settings the window really uses: how was it launched (tab menu, Start menu, `wsl` typed)?
4. Check `settings.json` for the font in `profiles.defaults` and in the profile; a yellow warning bar at the top
   of the tab means the named font was not found. A backup copy is kept next to the file (`settings.json.bak*`).
5. Render the glyph from the font file to prove the font is good.
