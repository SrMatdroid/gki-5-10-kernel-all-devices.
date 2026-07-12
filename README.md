# hyperperf+
Kernel GKI 5.10 — garnet

Custom GKI 5.10 kernel for **Redmi Note 13 Pro 5G (garnet)** on HyperOS/MIUI Android 16.
Fork of [Steambot12/Templar-Kernel-GKI-5.10](https://github.com/Steambot12/Templar-Kernel-GKI-5.10) (android12-5.10, KMI generation 9).

---

## Features

- **Vorpal CPUFreq Governor v2.0** — by Steambot12
- **ThinLTO** — Full LTO needs ~12GB RAM during link, ThinLTO needs ~4GB
- **SCHED_PREFER_SILVER** — bias towards A55 cores for better battery life
- **TCP BBR** as default congestion control
- **Kyber I/O scheduler**
- **CAKE network QoS**
- **ZPOOL** (zswap backend)
- **F2FS compression**
- **EROFS per-CPU kthreads** (with high priority)
- **PM_WAKELOCKS_LIMIT=0** — no wakelock limit

---

## Requirements

- Ubuntu 22.04+ (or any distro with recent packages)
- Clang/LLVM 16
- aarch64-linux-gnu- cross compiler
- flex, bison, libncurses-dev, libelf-dev, libssl-dev

```bash
sudo apt install clang-16 lld-16 llvm-16 gcc-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu flex bison libncurses-dev python3 \
    libelf-dev libssl-dev
```

---

## Build

```bash
cd templar-kernel-garnet

# For garnet only (with device check)
./build-garnet.sh

# For any GKI 5.10 device (public, no device check)
./build-public.sh
```

The garnet build uses the full optimization fragment including Vorpal governor and device-specific tweaks. The public build only enables safe options (ThinLTO, BBR, Kyber, CAKE, ZPOOL, F2FS compression, EROFS kthreads).

Output:
- `~/kernel-output/TemplarKernel-GKI5.10-garnet.zip`
- `~/kernel-output-public/TemplarKernel-GKI5.10-Public.zip`
- Uncompressed `Image` is also copied

---

## Flash

**Recovery (OrangeFox / TWRP):**
Flash the zip directly. The garnet version checks for device name (garnet/GARNET) before flashing.

**Fastboot:**
```bash
fastboot flash boot boot.img
fastboot reboot
```

**Always backup your stock boot.img before flashing.**

---

## AnyKernel3

The build script clones [AnyKernel3](https://github.com/osm0sis/AnyKernel3) automatically to `/tmp/anykernel3`. It uses `dump_boot` + `write_boot` with auto slot detection.

If you already have it at `~/anykernel3`, change the path in the script.

---

## Notes

- GKI 2.0 compatible (KMI generation 9, android12-5.10)
- Tested on HyperOS Android 16 (garnet)
- Unlocked bootloader required
- Works with Magisk + KPatch-Next-Module (KPM)
- With 16GB RAM or less, ThinLTO is required to avoid OOM during linking

---

## Credits

- **[Steambot12](https://github.com/Steambot12)** — Templar Kernel base, Vorpal CPUFreq Governor v2.0
- **Google / AOSP** — android12-5.10 GKI common kernel
- **[osm0sis](https://github.com/osm0sis)** — AnyKernel3
- **@kantsel1** — KPatch-Next for KPM module support

```
SrMatdroid — 2026
```
