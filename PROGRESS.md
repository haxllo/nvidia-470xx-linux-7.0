# NVIDIA 470.256.02 Driver — Kernel 7.0 Build Status

## System
- **GPU**: NVIDIA GeForce GT 720 (GK208, Kepler)
- **Driver**: 470.256.02 (last proprietary driver supporting Kepler)
- **Kernel**: 7.0.9-arch1-1
- **OS**: Arch Linux

## Status: ALL MODULES COMPILE AND WORK

| Module | Status |
|--------|--------|
| `nvidia.ko` (70M) | **Working** |
| `nvidia-uvm.ko` (47M) | **Working** |
| `nvidia-modeset.ko` (3.4M) | **Working** |
| `nvidia-drm.ko` (216K) | **Working** |
| `nvidia-peermem.ko` (392K) | **Working** |

## Verified Functionality
- `nvidia-smi` reports GT 720, 470.256.02, CUDA 11.4, 972 MiB VRAM
- Xorg uses NVIDIA driver (DRI2/VDPAU enabled)
- OpenGL linkage (`gcc -lGL` compiles and links)
- picom compositor with xrender backend (GLX caused freezes on this GPU)
- All userspace libraries installed (50 .so files)
- Soname symlinks created from ELF SONAME headers
- Nouveau blacklisted
- Kernel modules autoloaded at boot

## Kernel 7.0 Incompatibilities Fixed
1. **conftest.sh fails** — `static_assert` in kernel headers breaks compile tests; auto-corrected via `generate_version_overrides` command
2. **EXTRA_CFLAGS removed** — replaced with `ccflags-y`
3. **`__vma_start_write` (EXPORT_SYMBOL_GPL)** — bypassed via direct `vma_flags_set_word`/`vma_flags_clear_word`
4. **`follow_pfnmap_start/end` (EXPORT_SYMBOL_GPL)** — replaced with manual x86 page table walk
5. **`set_close_on_exec` not exported** — replaced with `__set_bit` on `fdt->close_on_exec`
6. **`del_timer_sync` removed** — compat define to `timer_delete_sync`
7. **`in_irq` removed** — compat define to `in_hardirq`
8. **`follow_pfn`/`unsafe_follow_pfn` removed** — manual page table walk

## Patch
All source code changes are in a single unified patch:
- `nvidia-470xx-fix-linux-7.0.patch` (329 lines, 9 files)
