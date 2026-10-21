# How to troubleshoot a WSL problem

Every problem in this setup was solved the same way: split the path from cause to symptom into stages, and
test each stage on its own, so that a pass or a fail rules a whole stage in or out.

## The method

1. **Write down the symptom exactly.** "Icons are wrong" is vague. "Three icons show `�`, the rounded edges
   draw fine" says the font works for some symbols and not others.
2. **List the stages between you and the symptom.** For icons: config → tmux → terminal → font → screen.
   For VSCodium: Flatpak sandbox → start script → Electron → display server.
3. **Test the stage nearest the cause first, with the layer above it removed.** Remove tmux and print the
   characters from a plain shell. Remove the terminal and render the glyphs from the font file directly.
4. **Capture evidence instead of guessing.** Raw bytes, a log with verbose flags, a timestamp, a process list.
5. **Change one thing, then re-test the same stage.** Two simultaneous changes make a pass unexplainable.
6. **Record what was ruled out.** A short "not the cause" list stops you repeating the work.

## Tools that were useful

| Question | Command |
|---|---|
| What does a program say when it dies? | Run it with a timeout and save the log: `timeout 20 prog > log 2>&1; echo $?` (exit 124 means it was still running, so it started) |
| Does Linux see the GPU? | `ls /dev/dri /dev/dxg` (WSL has `/dev/dxg` only) |
| What did tmux send to the terminal? | `script -q -c "timeout 3 tmux attach -r" out.bin`, then count codepoints in `out.bin` |
| Does a font file contain a symbol? | `fc-query -f '%{charset}\n' file.ttf`, or render it: `pango-view --font=... -t "$(printf '')"` |
| Which Windows process started a window? | `powershell.exe` with `Get-CimInstance Win32_Process`, walking `ParentProcessId` |
| When did a Windows program start vs. when did I change something? | `Get-Process Name \| Select StartTime` and `ls -l --time-style=+%H:%M` |
| What did a scheduled task last do? | `Get-ScheduledTaskInfo -TaskName X` (`LastRunTime`, `LastTaskResult`; 0 is success) |
| What does the kernel say about a disk? | `dmesg \| tail` |
| Why did a plugin install fail? | The installer's own log (tpm writes `~/.tmux/plugins/tpm_log.txt`) |

## WSL-specific habits

- WSL runs Linux inside a virtual machine, and Windows owns the screen, the GPU and the disks. Most surprises
  come from that boundary.
- A change on the Windows side often takes effect only after a program restarts (`wsl --shutdown`, Windows
  Terminal). Always compare the program's start time with the time of your change.
- The Bash tool used by Claude Code may run zsh, not fish. A command stored in a variable and run unquoted
  behaves differently there. Wrap tests in `bash -c '...'`.
- Programs started from Linux with `.exe` run as your Windows user without admin rights.
