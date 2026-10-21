# Graphical apps and desktops on CachyOS in WSL

## What works

Single Linux GUI apps, through WSLg (Microsoft's GUI layer for WSL). Each app opens as its own window on the
Windows desktop. They also appear in the Windows Start menu as `<name> (cachyos)`.

- Start from the Start menu, or from a terminal: `dolphin & disown` (`disown` keeps the app alive when the
  terminal closes in fish).
- Install apps with `pacman` or `yay`; shortcuts appear by themselves.
- Copy and paste work across Windows and Linux. Windows drives are at `/mnt/c`, `/mnt/d`; Linux files are at
  `\\wsl$\cachyos` in Windows.

## Why a client app works and Hyprland does not

- An **app** (client) asks a compositor for a window, draws into memory and hands the picture over.
- A **compositor** arranges all windows, handles input and sends the final picture to the screen.
- WSLg runs its own compositor (Weston) and forwards the pictures to Windows over Remote Desktop Protocol.
  Windows is the desktop; Linux apps are guests.

Hyprland is a compositor. It can start in two ways, and WSL fails both:

| Way | Needs | WSL |
|---|---|---|
| Own the screen (DRM) | `/dev/dri` graphics device and a "seat" from logind/seatd | Neither exists. The GPU is only reachable through `/dev/dxg` (DirectX 12). |
| Run as a window inside another compositor | Specific Wayland protocols and a render device to make buffers | WSLg's compositor reported "Missing protocols"; no render device ("no allocator available") |

Evidence: `Hyprland -c /etc/skel/.config/hypr/hyprland.lua` crashed with `CBackend::create() failed`; the
aquamarine log lines were `libseat: failed to open a seat`, `Wayland backend cannot start: Missing protocols`,
`Cannot open backend: no allocator available`. Microsoft's WSLg documentation states that it "does not provide a
full desktop experience". Which protocol is missing was not checked (linux-dmabuf is the likely one).

## Options considered

| Option | Outcome |
|---|---|
| Single apps through WSLg | **Recommended for daily use.** Officially supported, GPU-accelerated. |
| Hyprland | Cannot run (above). Waits for a bare-metal install. |
| niri in a WSLg window | **Works** (see below); feels like an app |
| Sway/labwc in a window | Plausible (wlroots can draw on the CPU) but never tested |
| XFCE over `xrdp` (Remote Desktop to `localhost`) | The common full-desktop setup on WSL. Not built: `xrdp` is an AUR package, and it is X11, not Wayland. |
| niri over `xrdp` | Impossible: `xrdp` needs an X11 display server; niri is a Wayland compositor with no remote-desktop or VNC mode in its docs |
| Bare-metal CachyOS on the spare 2 TB disk | The way to get a native niri/Hyprland desktop. Not done yet. |

Ubuntu is no different: Microsoft and Canonical support WSLg apps only. Full Ubuntu desktops in WSL are
community setups (xrdp + XFCE, or GNOME via Xwayland scripts).

## niri in a WSLg window

- Package `cachyos-niri-noctalia` (it conflicts with `cachyos-hypr-noctalia`, which was removed). Its config
  from `/etc/skel` is in the dotfiles; the terminal shortcut was changed from Alacritty (not installed) to kitty.
- Start with `niri-wsl`. It sets `GALLIUM_DRIVER=d3d12` and `MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA`.
- Mod key is Alt (Windows keeps Super). Ctrl+Alt+Delete quits niri.

How the GPU question was answered: niri's log prints `GL Renderer`. Default: `llvmpipe` (CPU).
With `GALLIUM_DRIVER=d3d12`: `D3D12 (AMD Radeon(TM) Graphics)` (the integrated GPU, picked first).
With `MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA`: `D3D12 (NVIDIA GeForce RTX 4090)`.

Why it feels non-native: Windows draws its own mouse pointer and niri draws a second one inside its window,
delayed by the trip through Remote Desktop; Super belongs to Windows; the window sits among other Windows
windows. An invisible-pointer theme would hide the second pointer but also remove cursor shapes. Not worth it.

Known limit: X11 apps cannot run inside niri, because `xwayland-satellite` refuses `/tmp/.X11-unix`
("missing the sticky bit"). They open as separate WSLg windows.

## Troubleshooting a GUI app that will not start

1. `echo $WAYLAND_DISPLAY $DISPLAY $XDG_RUNTIME_DIR` should show `wayland-0`, `:0`, `/run/user/1000`.
2. `ls /run/user/1000/wayland-0` must exist. If not, WSLg did not start; run `wsl --shutdown` and reopen.
3. Run the app with a timeout and save the log; search it for `display`, `wayland`, `ozone`, `EGL`, `DRI`.
4. `Missing X server or $DISPLAY` means the app chose X11 but could not reach it (see vscodium-flatpak.md).
5. `failed to get driver name` / `ZINK ... VK_ERROR_INCOMPATIBLE_DRIVER` warnings are normal under WSL: Mesa
   tries other drivers before d3d12. They are harmless if the app starts.
6. Slow or CPU-drawn app: try `GALLIUM_DRIVER=d3d12` (not yet checked for ordinary apps).
7. Microsoft's guide: "Diagnosing cannot open display type issues with WSLg" (microsoft/wslg wiki).
