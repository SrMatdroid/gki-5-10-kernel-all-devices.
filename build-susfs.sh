#!/bin/bash
LOG="$HOME/build-susfs.log"
(
START=$(date +%s)
echo "=== SrMatdroid Kernel GKI 5.10 + KSU + SUSFS ==="
echo "Started: $(date)"

ROOT_DIR="/home/sarkot/templar-kernel-public"
OUTPUT_DIR="$HOME/kernel-output-susfs"
SUSFS_DIR="/tmp/susfs4ksu"
BUILD_SUFFIX="-ge4f8b2c-$(date +%y%m%d)"
MAX_JOBS=2

export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang LLVM=1 LLVM_IAS=1

cd "$ROOT_DIR"

echo "[1] Cleaning..."
rm -rf KernelSU KernelSU-Next 2>/dev/null
git checkout . 2>/dev/null
touch .scmversion

echo "[2] Cloning SUSFS..."
[ -d "$SUSFS_DIR" ] || git clone --depth=1 --branch=gki-android12-5.10 https://gitlab.com/simonpunk/susfs4ksu.git "$SUSFS_DIR"

echo "[2.5] Applying FAST CHARGER..."
grep -q "CONFIG_FAST_CHARGER" drivers/power/supply/Kconfig || \
  sed -i '/endif # POWER_SUPPLY/i\config FAST_CHARGER\n\ttristate "Fast charger control for GKI kernels"\n\tdepends on POWER_SUPPLY\n\thelp\n\t  Say Y here to enable fast charge control via sysfs.\n\t  Adds \/sys\/class\/power_supply\/battery\/fastcharge_mode,\n\t  \/sys\/class\/power_supply\/battery\/fcc_max, and\n\t  \/sys\/class\/power_supply\/battery\/icl_max nodes.\n' drivers/power/supply/Kconfig
grep -q "fast-charger" drivers/power/supply/Makefile || \
  echo "obj-\$(CONFIG_FAST_CHARGER) += fast-charger.o" >> drivers/power/supply/Makefile
[ -f drivers/power/supply/fast-charger.c ] || echo "WARNING: fast-charger.c not found"

echo "[3] Applying SUSFS patches..."
cp "$SUSFS_DIR/kernel_patches/fs/susfs.c" fs/susfs.c
cp "$SUSFS_DIR/kernel_patches/include/linux/susfs.h" include/linux/susfs.h
cp "$SUSFS_DIR/kernel_patches/include/linux/susfs_def.h" include/linux/susfs_def.h
patch -p1 -N -r /dev/null < "$SUSFS_DIR/kernel_patches/50_add_susfs_in_gki-android12-5.10.patch"

echo "[4] Cloning KernelSU..."
git clone --depth=1 https://github.com/tiann/KernelSU.git KernelSU

echo "[5] Applying SUSFS for KSU..."
cd KernelSU
patch -p1 -N -r /dev/null < "$SUSFS_DIR/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch"
cd "$ROOT_DIR"

echo "[6] Integrating KSU..."
ln -sf "$ROOT_DIR/KernelSU/kernel" drivers/kernelsu
grep -q "kernelsu" drivers/Makefile || echo "obj-\$(CONFIG_KSU) += kernelsu/" >> drivers/Makefile
grep -q "kernelsu/Kconfig" drivers/Kconfig || sed -i "/endmenu/i\source \"drivers/kernelsu/Kconfig\"" drivers/Kconfig

echo "[7] Configuring..."
make gki_defconfig
./scripts/kconfig/merge_config.sh -m -O . \
    arch/arm64/configs/gki_defconfig \
    arch/arm64/configs/hyperos_optimized.fragment \
    arch/arm64/configs/ksu.fragment
echo "CONFIG_LOCALVERSION=\"${BUILD_SUFFIX}\"" >> .config
echo "CONFIG_FAST_CHARGER=y" >> .config
make olddefconfig
grep -q "CONFIG_KSU=y" .config || echo "WARNING: CONFIG_KSU not enabled"

echo "[8] Building..."
echo "  CC: $(clang --version | head -1)"
nice -n 19 make -j$MAX_JOBS

[ -f arch/arm64/boot/Image ] || { echo "ERROR: Image not generated"; exit 1; }

echo "[9] AnyKernel3..."
mkdir -p "$OUTPUT_DIR"
cp arch/arm64/boot/Image "$OUTPUT_DIR/Image"

AK3_DIR="/tmp/anykernel3"
[ -d "$AK3_DIR" ] || git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "$AK3_DIR"

cat > "$AK3_DIR/anykernel.sh" << 'AK3'
properties() { '
kernel.string=SrMatdroid Kernel GKI 5.10
do.devicecheck=0
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; }
BLOCK=boot
IS_SLOT_DEVICE=auto
RAMDISK_COMPRESSION=auto
PATCH_VBMETA_FLAG=auto
. tools/ak3-core.sh
dump_boot
write_boot
AK3

cp "$OUTPUT_DIR/Image" "$AK3_DIR/Image"
cd "$AK3_DIR"
rm -f "$OUTPUT_DIR/Kernel-GKI5.10-SUSFS.zip"
zip -r9 "$OUTPUT_DIR/Kernel-GKI5.10-SUSFS.zip" * -x ".git/*" "README.md" "LICENSE"

cd "$ROOT_DIR"
END=$(date +%s)
echo ""
echo "=== COMPLETED ==="
echo "  Started: $(date -d @$START)"
echo "  Ended:   $(date -d @$END)"
echo "  Elapsed: $(( (END - START) / 60 ))m $(( (END - START) % 60 ))s"
echo "  Output: $OUTPUT_DIR/"
echo "  ZIP:    $(du -h "$OUTPUT_DIR/Kernel-GKI5.10-SUSFS.zip" | cut -f1)"
) 2>&1 | tee "$LOG"
