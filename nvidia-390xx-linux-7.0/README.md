# nvidia-390xx-linux-7.0

An experimental patch-application workflow for building NVIDIA 390.157 against
Linux kernel 7.0. It targets x86_64 systems and does not include NVIDIA's
driver source or installer.

NVIDIA 390.157 is the final legacy branch for Fermi GPUs, including the Tesla
C2070. This project is separate from the 470-series Kepler driver project.

## Status

The maintained Arch AUR [`nvidia-390xx-utils`](https://aur.archlinux.org/packages/nvidia-390xx-utils)
series includes Linux 7.0 compatibility patches. The helper downloads the
audited AUR revision, verifies the exact SHA-256 hashes listed in this
repository, then applies the patches in the package's documented order.

This workflow has been statically validated against NVIDIA's official
390.157 runfile: its integrity check passed and every patch in the Linux 7.0
series applied cleanly. It has **not** yet been built, booted, or runtime-tested
on Ubuntu with a Fermi GPU. In particular, it does not establish that the
SimpleDRM handoff works.

## Test procedure

Do this only on a system with a known-working fallback kernel available in
GRUB. Record the Ubuntu release, `uname -r`, installation method for any
existing 390 package, and Secure Boot state before starting.

```bash
git clone https://github.com/haxllo/nvidia-390xx-linux-7.0.git
cd nvidia-390xx-linux-7.0

wget https://us.download.nvidia.com/XFree86/Linux-x86_64/390.157/NVIDIA-Linux-x86_64-390.157.run
sh NVIDIA-Linux-x86_64-390.157.run --check
sh NVIDIA-Linux-x86_64-390.157.run --extract-only

# Confirms the patch set applies without modifying the extracted source.
./scripts/apply-aur-patches.sh --source NVIDIA-Linux-x86_64-390.157 --dry-run

# Applies the patch set to the extracted source.
./scripts/apply-aur-patches.sh --source NVIDIA-Linux-x86_64-390.157
```

The final install step should be performed only after the existing package
state and Ubuntu-specific procedure are understood. NVIDIA's installer requires
the graphical session to be stopped and Nouveau to be disabled before it runs;
see NVIDIA's [installation guide](https://download.nvidia.com/XFree86/Linux-x86_64/390.157/README/installdriver.html).

The extracted tree can then be used by the bundled installer:

```bash
cd NVIDIA-Linux-x86_64-390.157
sudo ./nvidia-installer
```

Using the `.run` installer alongside distribution packages can overwrite or
conflict with packaged files. Do not use this as a replacement for the
Debian/Ubuntu package path until it has been tested for the target system.

## What to report after testing

After rebooting into kernel 7.0, report:

```bash
uname -r
nvidia-smi
dmesg -T | grep -iE 'nvidia|nvrm|drm'
```

For a Tesla C2070, also run a known CUDA workload or NVIDIA's `deviceQuery`
sample if CUDA is installed. A C2070 is a compute card, so CUDA validation is
more relevant than testing a connected display.

## Provenance and licensing

The patch file names, hashes, and application order are recorded in
[`patches/`](patches/). The reference AUR revision is
[`e0f6ac587b2e2d40af7929c57a1f827082872585`](https://aur.archlinux.org/cgit/aur.git/commit/?h=nvidia-390xx-utils&id=e0f6ac587b2e2d40af7929c57a1f827082872585).
The AUR package documents individual patch attribution in its `PKGBUILD`.

Repository scripts and documentation are licensed under [GPL-2.0-only](LICENSE).
NVIDIA's driver remains subject to NVIDIA's license; see [NOTICE](NOTICE).
