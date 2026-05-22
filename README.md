# nvidia-470xx-linux-7.0

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue?style=flat-square)](LICENSE)
[![Kernel](https://img.shields.io/badge/Kernel-7.0.x-blue?style=flat-square)](#)
[![Driver](https://img.shields.io/badge/Driver-470.256.02-76b900?style=flat-square)](#)
[![Release](https://img.shields.io/github/v/release/haxllo/nvidia-470xx-linux-7.0?style=flat-square)](https://github.com/haxllo/nvidia-470xx-linux-7.0/releases/latest)

> Build and install NVIDIA 470.256.02 (the final Kepler-supporting driver) on Linux kernel 7.0 — for any distribution.

GeForce GT/GTX 6xx/7xx (Kepler) owners have been stuck since NVIDIA dropped support after driver 470. This patch gets that driver compiling and running on kernel 7.0.

## Features

- All 5 kernel modules compile with zero errors: `nvidia`, `nvidia-uvm`, `nvidia-modeset`, `nvidia-drm`, `nvidia-peermem`
- Automatic conftest correction — no manual macro overrides needed
- Xorg, OpenGL, CUDA 11.4, Vulkan, VDPAU, NVENC/NVDEC all functional
- Single unified patch, works on any distro

## Prerequisites

- Linux kernel 7.0+
- Kernel headers installed matching your running kernel
- GCC, make, and standard build tools
- Xorg server and `libglvnd` (for OpenGL/GLX)

## Quick start

```bash
# 1. Download and extract the NVIDIA driver
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/470.256.02/NVIDIA-Linux-x86_64-470.256.02.run
sh NVIDIA-Linux-x86_64-470.256.02.run --extract-only
cd NVIDIA-Linux-x86_64-470.256.02/kernel

# 2. Apply the patch
patch -p1 -i /path/to/nvidia-470xx-fix-linux-7.0.patch

# 3. Build kernel modules
make modules

# 4. Install modules
sudo make modules_install
sudo depmod -a

# 5. Install userspace libraries
# See "Full installation" below
```

> [!TIP]
> The patch includes `generate_version_overrides` which reads `LINUX_VERSION_CODE` from your kernel headers and auto-corrects macro detection. No manual overrides needed on kernel 7.0. Override results are stored in `conftest/overrides.h` and included last in the conftest chain to prevent other generated files from undoing them.

## Full installation

### Userspace libraries

The extracted driver directory (`NVIDIA-Linux-x86_64-470.256.02/`) contains all the `.so` libraries, Xorg driver, Vulkan ICD, OpenCL, and binaries. The [PKGBUILD](PKGBUILD) lists every file with its install location — reference it regardless of your distro.

**Key files to install:**

| Category | Files |
|---|---|
| CUDA | `libcuda.so.470.256.02`, `libnvcuvid.so.470.256.02` |
| OpenGL/GLX | `libGLX_nvidia.so.470.256.02`, `libnvidia-glcore.so.470.256.02`, `libnvidia-eglcore.so.470.256.02` |
| GLES | `libGLESv1_CM_nvidia.so.470.256.02`, `libGLESv2_nvidia.so.470.256.02` |
| Vulkan | `libnvidia-glvkspirv.so.470.256.02`, `nvidia_icd.json` |
| VDPAU | `libvdpau_nvidia.so.470.256.02 → /usr/lib/vdpau/` |
| NVENC/NVDEC | `libnvidia-encode.so.470.256.02`, `libnvidia-fbc.so.470.256.02` |
| Xorg driver | `nvidia_drv.so → /usr/lib/xorg/modules/drivers/`, `libglxserver_nvidia.so.470.256.02` |
| nvidia-smi | `nvidia-smi`, `nvidia-modprobe`, `nvidia-xconfig`, `nvidia-persistenced` |
| OpenCL | `libnvidia-opencl.so.470.256.02`, `nvidia.icd` |

### Post-install config

```bash
# Blacklist nouveau
echo "blacklist nouveau" | sudo tee /usr/lib/modprobe.d/nvidia-470xx.conf

# Autoload modules at boot
printf "nvidia-uvm\nnvidia-modeset\nnvidia-drm\n" | sudo tee /usr/lib/modules-load.d/nvidia-470xx.conf

# Xorg config — adjust BusID to match your GPU
cat > /etc/X11/xorg.conf.d/20-nvidia.conf << 'EOF'
Section "Device"
    Identifier  "NVIDIA"
    Driver      "nvidia"
    BusID       "PCI:41:0:0"
EndSection
EOF
```

Find your BusID: `lspci | grep VGA` → `29:00.0` means domain 0, bus 0x29 (= 41 decimal), so `PCI:41:0:0`.

### Verify

```bash
nvidia-smi
lsmod | grep nvidia
glxinfo | grep "OpenGL vendor"
```

## How it works

NVIDIA's driver build uses `conftest.sh` to probe the kernel API by compiling small C programs. On kernel 7.0, `static_assert` in kernel headers causes these probes to fail silently, producing wrong `#undef` results. The patch addresses four categories of breakage:

1. **Conftest auto-correction** — `generate_version_overrides` reads `LINUX_VERSION_CODE` and overrides 20+ wrongly detected macros
2. **Build system** — `EXTRA_CFLAGS` removed in kernel 7.0; replaced with `ccflags-y`
3. **GPL-only symbols** — `__vma_start_write`, `follow_pfnmap_start/end`, `set_close_on_exec` went GPL; bypassed with direct equivalents
4. **Removed APIs** — `del_timer_sync` → `timer_delete_sync`, `in_irq` → `in_hardirq`, `follow_pfn` → manual page table walk

All source changes are in a single unified patch against the driver's `kernel/` directory.

## Troubleshooting

### conftest.sh auto-correction not working

Check `conftest/functions.h` after building. If macros like `NV_FILE_HAS_INODE` show `#undef` on kernel 7.0, the version detection failed. Verify your kernel headers have `include/generated/uapi/linux/version.h`.

### Module load fails: unknown symbol

The patch handles all known GPL-only symbol issues. If you see new ones, check `dmesg` for the symbol name — it may need a similar workaround.

### picom compositor freezing

On Kepler GPUs, picom's GLX backend with `corner-radius` can freeze the screen. Use xrender instead:

```
backend = "xrender";
vsync = false;
```

### Module autoload

Ensure `depmod -a` was run after `make modules_install` and that `/usr/lib/modules-load.d/nvidia-470xx.conf` lists the module names.

## Patch index

| File | Patch |
|---|---|
| `nvidia-470xx-fix-linux-7.0.patch` | Unified patch (12 files, 416 lines) for kernel 7.0 |
| `nvidia-470xx-fix-linux-6.13.patch` through `6.19-part2.patch` | Patches for earlier kernels |
| `nvidia-470xx-fix-gcc-15.patch` | Fix for GCC 15 compatibility |
| `0001-0003-conftest-fix.patches` | Conftest cross-distribution fixes |
| `PKGBUILD` | AUR packaging (update `sha512sums` before use) |

## Changelog

See [PROGRESS.md](PROGRESS.md) for the full build log and change history.

## License

The patches and documentation in this repository are licensed under [GNU General Public License v2](LICENSE).

The NVIDIA driver itself is proprietary software — this repository contains only the modifications needed to make it compile on kernel 7.0.
