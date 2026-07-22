#!/usr/bin/env bash
# WezTerm GPU-safe launcher (self-adapting). On hybrid iGPU + discrete-NVIDIA
# laptops the iGPU userspace stack (Mesa/iris EGL) is often not ready in the ~1s
# window when i3 autostarts terminals at login, while the NVIDIA Vulkan ICD
# already is; wezterm picks its adapter ONCE at GUI start with no retry, falls
# back to the dGPU and pins it awake (RTD3 never engages). Hiding NVIDIA from
# wezterm's Vulkan/EGL enumeration makes the dGPU physically unselectable.
# Acts ONLY when both an nvidia and a non-nvidia DRM card exist; pure-dGPU
# desktops, pure-iGPU and AMD-only boxes are untouched, and the session env is
# never changed so prime-run offload (gaming/streaming) keeps working.
set -euo pipefail

has_nv=0
has_other=0
for d in /sys/class/drm/card*/device/driver; do
    drv=$(basename "$(readlink "$d" 2>/dev/null)" 2>/dev/null) || continue
    [ -z "$drv" ] && continue
    case "$drv" in
        nvidia) has_nv=1 ;;
        *) has_other=1 ;;
    esac
done

if [ "$has_nv" = 1 ] && [ "$has_other" = 1 ]; then
    icd=$(grep -Li nvidia /usr/share/vulkan/icd.d/*.json 2>/dev/null | paste -sd:) || true
    egl=$(grep -Li nvidia /usr/share/glvnd/egl_vendor.d/*.json 2>/dev/null | paste -sd:) || true
    if [ -n "$icd" ]; then export VK_ICD_FILENAMES="$icd"; fi
    if [ -n "$egl" ]; then export __EGL_VENDOR_LIBRARY_FILENAMES="$egl"; fi
fi

exec wezterm "$@"
