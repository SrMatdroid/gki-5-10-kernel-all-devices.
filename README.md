# Templar Kernel GKI 5.10 - Redmi Note 13 Pro 5G (garnet)

Custom GKI 5.10 kernel based on android12-5.10, optimized for Redmi Note 13 Pro 5G running HyperOS/MIUI.

## Features

- Vorpal CPUFreq Governor v2.0
- ThinLTO enabled (reduces RAM usage during compilation)
- SCHED_PREFER_SILVER for better battery life
- TCP BBR congestion control
- Kyber I/O scheduler
- CAKE network QoS
- ZPOOL memory compression
- F2FS compression support
- EROFS per-CPU kthreads for faster decompression
- PM wakelocks limit removed

## Prerequisites

- Ubuntu 22.04+ (or any Debian-based distro)
- Clang/LLVM 16
- aarch64-linux-gnu- cross-compiler
- Python 3, flex, bison, libncurses-dev

### Install toolchain

```bash
sudo apt update
sudo apt install -y clang-16 lld-16 llvm-16 \
    gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    flex bison libncurses-dev python3 \
    libelf-dev libssl-dev
```

## Building

### For garnet (with device check)

```bash
./build-garnet.sh
```

Output goes to `~/kernel-output/`:
- `TemplarKernel-GKI5.10-garnet.zip` - flashable via recovery (AnyKernel3)
- `Image` - raw kernel image

### For any GKI 5.10 device (public build)

```bash
./build-public.sh
```

Output goes to `~/kernel-output-public/`:
- `TemplarKernel-GKI5.10-Public.zip` - flashable via recovery (AnyKernel3)
- `Image` - raw kernel image

Note: The public build uses only safe optimizations (no device-specific governors or scheduling changes).

## Flashing

### Via recovery (AnyKernel3)

1. Reboot to custom recovery (OrangeFox, TWRP, etc.)
2. Flash `TemplarKernel-GKI5.10-garnet.zip`
3. Reboot

### Via fastboot

```bash
fastboot flash boot boot.img
fastboot reboot
```

**Always backup your stock boot.img before flashing.**

## AnyKernel3

This repo uses [AnyKernel3](https://github.com/osm0sis/AnyKernel3) by osm0sis for zip generation. The build scripts auto-download it.

## Credits

- [Steambot12](https://github.com/Steambot12) - Templar Kernel base (Vorpal governor, kernel source)
- Google/ASOP - android12-5.10 GKI common kernel
- osm0sis - AnyKernel3
- @kantsel1 - KPatch-Next support

## Notes

- GKI 2.0 compatible (KMI generation 9)
- Tested on HyperOS based on Android 14
- Requires unlocked bootloader
- Compatible with Magisk + KPatch-Next-Module (KPM)
