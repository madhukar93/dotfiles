# WSL-specific configuration for Fish shell
# This file is automatically sourced by Fish on startup
#
# Purpose: Handle Windows mount point paths in WSL and set locale
# When WSL is launched from Windows (e.g., from File Explorer or Windows Terminal),
# it starts in the Windows working directory, which is mounted under /mnt/
# This provides a better UX by automatically changing to the Linux home directory.

# Check if current directory is a Windows mount point
if string match -q "/mnt/*" $PWD
    # Change to home directory for better WSL experience
    cd ~
end

# Set locale for GUI applications
# Read from /etc/locale.conf if it exists
if test -f /etc/locale.conf
    set -l locale_lang (grep '^LANG=' /etc/locale.conf | cut -d= -f2)
    if test -n "$locale_lang"
        set -gx LANG $locale_lang
        set -gx LC_ALL $locale_lang
    end
end

# WSLg support: Set XDG_RUNTIME_DIR to where WSLg mounts Wayland/DBus sockets
# WSLg provides Wayland, X11, and PulseAudio sockets in /mnt/wslg/runtime-dir
# This is required for GUI applications to work properly with WSLg
if test -d /mnt/wslg/runtime-dir
    set -gx XDG_RUNTIME_DIR /mnt/wslg/runtime-dir
    # With a systemd user session, use its runtime dir; WSL links wayland-0 into it
    test -S /run/user/(id -u)/bus; and set -gx XDG_RUNTIME_DIR /run/user/(id -u)
    set -gx WAYLAND_DISPLAY wayland-0
    set -gx DISPLAY :0

    # WSL has no /dev/dri, so Mesa draws on the CPU (llvmpipe) unless it is told to reach the GPU through
    # /dev/dxg with its d3d12 driver. Chromium/Electron apps blocklist WebGL on llvmpipe. Pick the NVIDIA
    # adapter, because d3d12 otherwise picks the integrated AMD one. Not yet verified for ordinary apps.
    set -gx GALLIUM_DRIVER d3d12
    set -gx MESA_D3D12_DEFAULT_ADAPTER_NAME NVIDIA
end
