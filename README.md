# Templar Kernel GKI 5.10 - garnet

Custom kernel for Redmi Note 13 Pro 5G (garnet) on HyperOS/MIUI.
Based on Steambot12's Templar Kernel GKI 5.10 (android12-5.10).

## Features

- Vorpal CPUFreq Governor v2.0
- ThinLTO (Full LTO se crasheaba con 16GB RAM)
- SCHED_PREFER_SILVER para mejor bateria
- TCP BBR + Kyber + CAKE
- ZPOOL, F2FS compression, EROFS pcpu kthread
- Sin limite de wakelocks

## Que necesitas

Clang/LLVM 16, cross-compiler aarch64, flex, bison, python3.

```bash
sudo apt install clang-16 lld-16 llvm-16 gcc-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu flex bison libncurses-dev python3 \
    libelf-dev libssl-dev
```

## Compilar

```bash
# Para garnet (con device check)
./build-garnet.sh
# -> ~/kernel-output/TemplarKernel-GKI5.10-garnet.zip

# Para cualquier GKI 5.10 (public build, sin device check)
./build-public.sh  
# -> ~/kernel-output-public/TemplarKernel-GKI5.10-Public.zip
```

## Flashear

- Recovery: flash el .zip con OrangeFox/TWRP
- Fastboot: `fastboot flash boot boot.img`

Siempre haz backup de tu boot.img original antes.

## Creditos

- [Steambot12](https://github.com/Steambot12) - Templar Kernel, Vorpal governor
- Google/AOSP - android12-5.10 GKI
- osm0sis - AnyKernel3
- @kantsel1 - KPatch-Next

## Notas

- GKI 2.0, KMI gen 9
- Probado en HyperOS Android 14
- Bootloader desbloqueado requerido
- Compatible con Magisk + KPatch-Next-Module
- Si tienes 16GB RAM o menos, ThinLTO es necesario para no OOM en el link
