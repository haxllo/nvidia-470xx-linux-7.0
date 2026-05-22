# NVIDIA 470.256.02 on Linux Kernel 7.0 (Arch Linux)

Patches and instructions to build & install the **last Kepler-supporting NVIDIA driver** (470.256.02) on **Linux kernel 7.0.9** (and likely later 7.x kernels).

**GPU**: GeForce GT 720 (GK208) — but any Kepler GPU (GT 600/700 series) should work.

## Prerequisites

- Arch Linux (or any distro with kernel 7.0+)
- `linux-headers` installed matching your running kernel
- Base-devel group (`gcc`, `make`, etc.)
- Xorg server and libglvnd

## Quick Start (Manual Build)

### 1. Get the driver

```bash
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/470.256.02/NVIDIA-Linux-x86_64-470.256.02.run
sh NVIDIA-Linux-x86_64-470.256.02.run --extract-only
cd NVIDIA-Linux-x86_64-470.256.02/kernel
```

### 2. Apply the patch

```bash
patch -p1 -i /path/to/nvidia-470xx-fix-linux-7.0.patch
```

### 3. Fix conftest results

The conftest.sh compile tests fail on kernel 7.0 because `static_assert` in kernel headers causes false negatives. You need to manually correct the results.

**Key manual overrides in `conftest/functions.h`:**

```c
// Fixes (changed from #undef to #define):
#define NV_FILE_HAS_INODE                       // f_inode exists
#define NV_KUID_T_PRESENT                       // kuid_t exists
#define NV_VM_FAULT_HAS_ADDRESS                 // vm_fault.address
#define NV_VM_FAULT_T_IS_PRESENT                // vm_fault_t
#define NV_MM_HAS_MMAP_LOCK                     // mmap_lock
#define NV_PROC_OPS_PRESENT                     // proc_ops
#define NV_TIMESPEC64_PRESENT                   // timespec64
#define NV_VM_AREA_STRUCT_HAS_CONST_VM_FLAGS    // const vm_flags
#define NV_VM_OPS_FAULT_REMOVED_VMA_ARG         // vma arg removed in 4.17
#define NV_EFI_ENABLED_ARGUMENT_COUNT 1
#define NV_FULL_NAME_HASH_ARGUMENT_COUNT 3
#define NV_WAIT_ON_BIT_LOCK_ARGUMENT_COUNT 3   // 3-arg version in 7.0
#define NV_ACPI_WALK_NAMESPACE_ARGUMENT_COUNT 7
#define NV_GET_USER_PAGES_REMOTE_PRESENT
#define NV_GET_USER_PAGES_REMOTE_HAS_ARGS_FLAGS_LOCKED  // 6-arg version

// Removed in 7.0 (changed from #define to #undef):
#undef NV_SET_CLOSE_ON_EXEC_PRESENT      // not exported
#undef NV_ACPI_BUS_GET_DEVICE_PRESENT
#undef NV_PHYS_TO_DMA_PRESENT
#undef NV_DMA_IS_DIRECT_PRESENT
#undef NV_DMA_MAP_RESOURCE_PRESENT
#undef NV_SET_MEMORY_ARRAY_UC_PRESENT
#undef NV_JIFFIES_TO_TIMESPEC_PRESENT
#undef NV_ACQUIRE_CONSOLE_SEM_PRESENT
#undef NV_UNSAFE_FOLLOW_PFN_PRESENT
```

### 4. Build

```bash
SYSSRC=/usr/lib/modules/$(uname -r)/build make modules
```

### 5. Install kernel modules

```bash
sudo make modules_install
sudo depmod -a
```

### 6. Install userspace libraries

```bash
cd ../   # back to NVIDIA-Linux-x86_64-470.256.02/
```

Copy the following to `/usr/lib/` (see the PKGBUILD in this repo for the complete list):

| Library | Purpose |
|---------|---------|
| `libcuda.so.470.256.02` | CUDA driver API |
| `libnvidia-opencl.so.470.256.02` | OpenCL |
| `libnvidia-compiler.so.470.256.02` | OpenCL compiler |
| `libGLX_nvidia.so.470.256.02` | GLX |
| `libEGL_nvidia.so.470.256.02` | EGL |
| `libGLESv1_CM_nvidia.so.470.256.02` | GLESv1 |
| `libGLESv2_nvidia.so.470.256.02` | GLESv2 |
| `libnvidia-glcore.so.470.256.02` | OpenGL core |
| `libnvidia-eglcore.so.470.256.02` | EGL core |
| `libnvidia-glsi.so.470.256.02` | GL system interface |
| `libnvidia-tls.so.470.256.02` | TLS |
| `libnvidia-ml.so.470.256.02` | Management library |
| `libnvidia-cfg.so.470.256.02` | Config library |
| `libnvidia-ptxjitcompiler.so.470.256.02` | PTX JIT |
| `libnvidia-encode.so.470.256.02` | NVENC |
| `libnvidia-ifr.so.470.256.02` | IFROn dows |
| `libnvidia-fbc.so.470.256.02` | Framebuffer capture |
| `libnvcuvid.so.470.256.02` | CUDA video decoder |
| `libnvidia-allocator.so.470.256.02` | Allocator |
| `libnvidia-glvkspirv.so.470.256.02` | Vulkan SPIR-V |
| `libnvidia-vulkan-producer.so.470.256.02` | Vulkan producer |
| `libnvidia-ngx.so.470.256.02` | NGX |
| `libnvoptix.so.470.256.02` | OptiX |
| `libnvidia-rtcore.so.470.256.02` | Ray tracing core |
| `libnvidia-cbl.so.470.256.02` | CBL |
| `libnvidia-opticalflow.so.470.256.02` | Optical flow |
| `libvdpau_nvidia.so.470.256.02` | VDPAU (→ `/usr/lib/vdpau/`) |

**Xorg driver:**

```bash
sudo install -D nvidia_drv.so /usr/lib/xorg/modules/drivers/nvidia_drv.so
sudo install -D libglxserver_nvidia.so.470.256.02 /usr/lib/nvidia/xorg/libglxserver_nvidia.so.470.256.02
sudo ln -s libglxserver_nvidia.so.470.256.02 /usr/lib/nvidia/xorg/libglxserver_nvidia.so.1
sudo ln -s libglxserver_nvidia.so.470.256.02 /usr/lib/nvidia/xorg/libglxserver_nvidia.so
```

**Create soname symlinks:**

```bash
find /usr/lib -type f -name '*.so*' -not -path '*xorg/*' -print0 | while IFS= read -d $'\0' _lib; do
    _soname=$(dirname "${_lib}")/$(readelf -d "${_lib}" | grep -Po 'SONAME.*: \[\K[^]]*' || true)
    [ -z "$_soname" ] && continue
    _base=$(echo "$_soname" | sed -r 's/(.*)\.so.*/\1.so/')
    [ -e "$_soname" ] || ln -s "$(basename "${_lib}")" "$_soname"
    [ -e "$_base" ] || ln -s "$(basename "$_soname")" "$_base"
done
```

**Binaries:**

```bash
sudo install -D nvidia-smi /usr/bin/nvidia-smi
sudo install -D nvidia-modprobe /usr/bin/nvidia-modprobe
sudo install -D nvidia-xconfig /usr/bin/nvidia-xconfig
sudo install -D nvidia-debugdump /usr/bin/nvidia-debugdump
sudo install -D nvidia-bug-report.sh /usr/bin/nvidia-bug-report.sh
sudo install -D nvidia-cuda-mps-server /usr/bin/nvidia-cuda-mps-server
sudo install -D nvidia-cuda-mps-control /usr/bin/nvidia-cuda-mps-control
sudo install -D nvidia-persistenced /usr/bin/nvidia-persistenced
```

**Vulkan ICD:**

```bash
sudo install -Dm644 nvidia_icd.json /usr/share/vulkan/icd.d/nvidia_icd.json
sudo install -Dm644 nvidia_layers.json /usr/share/vulkan/implicit_layer.d/nvidia_layers.json
```

**OpenCL ICD:**

```bash
sudo install -Dm644 nvidia.icd /etc/OpenCL/vendors/nvidia.icd
```

**GLVND EGL vendor:**

```bash
sudo install -Dm644 10_nvidia.json /usr/share/glvnd/egl_vendor.d/10_nvidia.json
```

### 7. Post-install configuration

**Blacklist nouveau:**

```bash
echo "blacklist nouveau" | sudo tee /usr/lib/modprobe.d/nvidia-470xx.conf
echo "alias nouveau off" | sudo tee -a /usr/lib/modprobe.d/nvidia-470xx.conf
```

**Autoload modules:**

```bash
printf "nvidia-uvm\nnvidia-modeset\nnvidia-drm\n" | sudo tee /usr/lib/modules-load.d/nvidia-470xx.conf
```

**Xorg config** (`/etc/X11/xorg.conf.d/20-nvidia.conf`):

```
Section "Device"
    Identifier  "NVIDIA"
    Driver      "nvidia"
    BusID       "PCI:41:0:0"   # Change to match your GPU's lspci address
EndSection
```

Find your BusID: `lspci | grep VGA` → `29:00.0` means bus 0x29 = 41 decimal, so `PCI:41:0:0`.

**Reboot** and verify:

```bash
nvidia-smi
lsmod | grep nvidia
glxinfo | grep "OpenGL vendor"
```

## Troubleshooting

### conftest.sh fails

This is the most common issue. The compile tests in conftest.sh fail on kernel 7.0+ because kernel headers contain `static_assert` that breaks the test compilations. See the "Fix conftest results" section above for the required manual overrides.

### GPL-only symbol errors on module load

If `insmod` fails with "Unknown symbol" for GPL-only symbols:

- `__vma_start_write` — fixed by calling `vma_flags_set_word`/`vma_flags_clear_word` directly (we already hold the mmap lock)
- `follow_pfnmap_start`/`follow_pfnmap_end` — replaced with manual x86 page table walk
- `set_close_on_exec` — use `__set_bit` on the fdtable's `close_on_exec` bitmap directly

### del_timer_sync not found

Kernel 7.0 removed `del_timer_sync`. Use `timer_delete_sync` instead. Both `nv.c` and `nvidia-modeset-linux.c` need this fix.

### picom freezes with GLX backend

The GLX backend with rounded corners (`corner-radius`) can cause screen freezes on older Kepler GPUs. Switch to the `xrender` backend and disable vsync in picom (let the NVIDIA driver handle vsync).

Recommended picom config:
```
backend = "xrender";
vsync = false;
```

### Module autoload fails

If modules don't load at boot, ensure:
1. `/usr/lib/modules-load.d/nvidia-470xx.conf` exists with module names
2. `nvidia-uvm` is listed first (it depends on `nvidia`, which autoloads)
3. `depmod -a` was run after installing the modules

## File Reference

| File | Purpose |
|------|---------|
| `nvidia-470xx-fix-linux-7.0.patch` | Unified source patch for kernel 7.0 compatibility |
| `PKGBUILD` | AUR-style PKGBUILD for building from source |
| `PROGRESS.md` | Build progress and status documentation |

## Other Kernel Versions

This repo also contains patches for other kernel versions in case you need them:
- `kernel-6.10.patch` through `kernel-6.19-part2.patch`
- `nvidia-470xx-fix-linux-6.13.patch` through `nvidia-470xx-fix-linux-6.19-part2.patch`
- `nvidia-470xx-fix-gcc-15.patch`
- `0001-0003-conftest-fix patches`

## How It Works

The NVIDIA driver uses `conftest.sh` at build time to probe the kernel API and generate the correct `#define`/`#undef` macros in `conftest/functions.h` and `conftest/types.h`. On kernel 7.0:

1. **Conftest breaks**: `static_assert` in modern kernel headers causes compile tests to fail, producing wrong `#undef` results for APIs that still exist
2. **EXTRA_CFLAGS removed**: Kernel build system no longer supports `EXTRA_CFLAGS`; must use `ccflags-y`
3. **GPL symbol protection**: Several symbols went from `EXPORT_SYMBOL` to `EXPORT_SYMBOL_GPL`, requiring workarounds
4. **API removals**: `del_timer_sync`, `in_irq`, `follow_pfn`, `unsafe_follow_pfn`, and several DMA/PCI APIs were removed

The unified patch handles all of these issues, and the manual conftest override table (above) corrects the remaining detection failures.

## License

NVIDIA driver is proprietary software. This repo contains only patch files and documentation.
