# nvidia-470xx-linux-7.0

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-yellow)](LICENSE)
[![Kernel](https://badgen.net/badge/Kernel/7.0.9/orange)](#)
[![Driver](https://badgen.net/badge/Driver/470.256.02/76b900)](#)
![Stars](https://badgen.net/github/stars/haxllo/nvidia-470xx-linux-7.0/)
[![Release](https://badgen.net/github/release/haxllo/nvidia-470xx-linux-7.0/)](https://github.com/haxllo/nvidia-470xx-linux-7.0/releases/latest)
> Build and install NVIDIA 470.256.02 (the final Kepler-supporting driver) on Linux kernel 7.0 — for any distribution.

GeForce GT/GTX 6xx/7xx (Kepler) owners have been stuck since NVIDIA dropped support after driver 470. This patch gets that driver compiling and running on kernel 7.0.

## Features

- All 5 kernel modules compile with zero errors: `nvidia`, `nvidia-uvm`, `nvidia-modeset`, `nvidia-drm`, `nvidia-peermem`
- Conftest probes detect the kernel correctly on 7.0, so no macro overrides are needed
- Xorg, OpenGL, CUDA 11.4, Vulkan, VDPAU, NVENC/NVDEC all functional
- The AUR patch series plus one small patch for 7.0; works on any distro, including Ubuntu's DKMS packages

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
cd NVIDIA-Linux-x86_64-470.256.02

# 2. Apply the patches, in this order, from the driver's kernel/ directory
PATCHES=/path/to/nvidia-470xx-linux-7.0
cd kernel
for p in \
    0001-Fix-conftest-to-ignore-implicit-function-declaration.patch \
    0002-Fix-conftest-to-use-a-short-wchar_t.patch \
    0003-Fix-conftest-to-use-nv_drm_gem_vmap-which-has-the-se.patch \
    nvidia-470xx-fix-gcc-15.patch \
    kernel-6.10.patch \
    kernel-6.12.patch \
    nvidia-470xx-fix-linux-6.13.patch \
    nvidia-470xx-fix-linux-6.14.patch \
    nvidia-470xx-fix-linux-6.15.patch \
    nvidia-470xx-fix-linux-6.17.patch \
    nvidia-470xx-fix-linux-6.19-part1.patch \
    nvidia-470xx-fix-linux-6.19-part2.patch \
    nvidia-470xx-fix-linux-7.0-dma-fence.patch
do
    patch -p1 -i "$PATCHES/$p" || { echo "FAILED: $p"; break; }
done
cd ..

# 3. Recommended: build and install the complete patched driver
sudo ./nvidia-installer
```

`nvidia-installer` builds from the patched `kernel/` directory and installs the driver components, including userspace libraries and utilities.

### Manual module installation (alternative)

Use these commands instead of `nvidia-installer` only when you intend to install the userspace components manually.

```bash
cd kernel
make modules

# Install modules
sudo make modules_install
sudo depmod -a

# Install userspace libraries
# See "Full installation" below
```

> [!TIP]
> The order matters: each patch expects the ones before it. The [PKGBUILD](PKGBUILD) applies the same list in the same order. On Ubuntu, `/usr/src/nvidia-470.256.02` (from `nvidia-kernel-source-470`) is the same `kernel/` directory apart from `dkms.conf`, so you can apply the patches there and run `sudo dkms install nvidia/470.256.02 -k $(uname -r)` instead of `nvidia-installer`, which keeps the userspace libraries apt installed.

## Full installation

### Userspace libraries

The extracted driver directory (`NVIDIA-Linux-x86_64-470.256.02/`) contains all the `.so` libraries, Xorg driver, Vulkan ICD, OpenCL, and binaries. The [PKGBUILD](PKGBUILD) shows many Arch-specific install locations; use it as a reference when completing the manual alternative.

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

### System configuration

Before either installation path, blacklist Nouveau, regenerate your distribution's initramfs if required, and stop the graphical session. The remaining configuration can be applied after installation.

```bash
# Blacklist nouveau before installation
echo "blacklist nouveau" | sudo tee /usr/lib/modprobe.d/nvidia-470xx.conf
```

After installation:

```bash
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

NVIDIA's driver build uses `conftest.sh` to probe the kernel API by compiling small C programs. Since 6.19 the kernel builds with `-fms-extensions`, and `include/linux/fs.h` relies on it: `struct filename` embeds an anonymous `struct __filename_head`. Without the flag, GCC drops that member, the `static_assert(sizeof(struct filename) % 64 == 0)` in the same header fails in every probe that includes it, and the probes report wrong results. `nvidia-470xx-fix-linux-6.19-part2.patch` adds the flag to the probes, so they detect the kernel correctly.

The patches address:

1. **Conftest** — the 0001–0003 patches and `-fms-extensions` (6.19-part2)
2. **Build system** — `EXTRA_CFLAGS` removed by the kernel; replaced with `ccflags-y`
3. **Kernel API changes from 6.10 to 6.19** — one patch per kernel release, from the AUR `nvidia-470xx-utils` package
4. **Kernel 7.0** — `dma_fence_signal()` now returns `void` (`nvidia-470xx-fix-linux-7.0-dma-fence.patch`)

All patches apply to the driver's `kernel/` directory with `patch -p1`.

`nvidia-470xx-fix-linux-7.0.patch` is the earlier single patch against the unpatched driver. It works around the wrong probe results with `generate_version_overrides`, which reads `LINUX_VERSION_CODE` and overrides 20+ macros. It changes the same lines as the series, so apply one or the other, not both.

## Troubleshooting

### A patch fails to apply

Start from a freshly extracted driver and apply the patches from its `kernel/` directory, in the order shown in the quick start. `nvidia-470xx-fix-linux-7.0.patch` cannot be combined with the series.

### Module load fails: unknown symbol

The patches handle all known GPL-only symbol issues. If you see new ones, check `dmesg` for the symbol name — it may need a similar workaround.

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
| `nvidia-470xx-fix-linux-7.0-dma-fence.patch` | Kernel 7.0: `dma_fence_signal()` returns `void` |
| `kernel-6.10.patch`, `kernel-6.12.patch`, `nvidia-470xx-fix-linux-6.13.patch` through `6.19-part2.patch` | Patches for earlier kernels |
| `nvidia-470xx-fix-linux-7.0.patch` | Earlier single patch (12 files, 416 lines) against the unpatched driver; not combinable with the series |
| `nvidia-470xx-fix-gcc-15.patch` | Fix for GCC 15 compatibility |
| `0001-0003-conftest-fix.patches` | Conftest cross-distribution fixes |
| `PKGBUILD` | Arch packaging reference; companion packaging files are required to build it |

## Changelog

See [PROGRESS.md](PROGRESS.md) for the full build log and change history.

## License

The patches and documentation in this repository are licensed under [GNU General Public License v2](LICENSE).

The NVIDIA driver itself is proprietary software — this repository contains only the modifications needed to make it compile on kernel 7.0.
