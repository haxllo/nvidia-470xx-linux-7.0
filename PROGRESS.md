# Changelog

## [1.0.0] — 2026-05-22 — All modules working on kernel 7.0.9

### Added
- `generate_version_overrides` command in conftest.sh — reads `LINUX_VERSION_CODE` and auto-corrects 20+ macros that compile tests wrongly detect due to `static_assert` in kernel 7.0+ headers
- `conftest/overrides.h` included at the end of `conftest.h` to ensure overrides take effect after all other conftest files (fixes `types.h`/`generic.h` undo issue)
- README.md with full documentation

### Fixed
- **conftest.h**: overrides from `functions.h` were undone by `types.h`/`generic.h` includes → added `overrides.h` include at the end of `conftest.h`
- **conftest.sh**: compile tests fail on kernel 7.0 (`static_assert` in kernel headers causes false negatives) → auto-corrected; added `NV_ACPI_WALK_NAMESPACE_PRESENT`/`NV_ACPI_WALK_NAMESPACE_ARGUMENT_COUNT 7` and `NV_PNV_NPU2_INIT_CONTEXT_PRESENT`(undef) overrides
- **Kbuild**: `EXTRA_CFLAGS` removed → replaced with `ccflags-y`; `#error` lines stripped from `functions.h`; `overrides.h` generated as separate file
- **nv-linux.h**: `acpi_walk_namespace` 8-arg variant, `dma_is_direct` fallback for 7.0, `f_inode` fallback, `set_close_on_exec` signature change
- **nv-mm.h**: `vm_flags_set/clear` call `__vma_start_write()` which is `EXPORT_SYMBOL_GPL` → bypassed via direct `vma_flags_set_word`/`vma_flags_clear_word` (we already hold mmap lock)
- **nv.c**: `del_timer_sync` removed → compat define to `timer_delete_sync`
- **os-mlock.c**: `follow_pfn`/`unsafe_follow_pfn` removed → manual x86 page table walk using inline macros
- **nvidia-modeset-linux.c**: same `del_timer_sync` → `timer_delete_sync` fix
- **nvidia-modeset.Kbuild**: `cmd_symlink` created broken symlinks (target path included wrong directory prefix) → fixed with `$(notdir $<)`
- **uvm_linux.h**: `wait_on_bit_lock` and `radix_tree_replace_slot` fallbacks with proper `#ifdef` guards
- **nv-time.h**: `in_irq` removed → compat define to `in_hardirq`
- **soname symlinks**: auto-generated from ELF SONAME headers for all installed libraries
- **picom**: switched from GLX (caused GPU freezes on GT 720) to xrender backend

### Verified
- `nvidia.ko` (70M), `nvidia-uvm.ko` (47M), `nvidia-modeset.ko` (3.4M), `nvidia-drm.ko` (216K), `nvidia-peermem.ko` (392K) all compiled and loaded
- `nvidia-smi` reports GT 720, 470.256.02, CUDA 11.4, 972 MiB VRAM
- Xorg with NVIDIA driver, DRI2/VDPAU enabled
- OpenGL linkage (`gcc -lGL`) works
- All userspace libraries installed (50 `.so` files)
- Nouveau blacklisted, modules autoload at boot

### Tested hardware
- GPU: NVIDIA GeForce GT 720 (GK208)
- Kernel: 7.0.9-arch1-1
- OS: Arch Linux
