#!/bin/bash
LOG="$HOME/build-susfs.log"
(
echo "=== Build Kernel GKI 5.10 + KSU + SUSFS ==="
echo "Log: $LOG"
echo ""

ROOT_DIR="/home/sarkot/templar-kernel-public"
OUTPUT_DIR="$HOME/kernel-output-susfs"
SUSFS_DIR="/tmp/susfs4ksu"
BUILD_SUFFIX="-ge4f8b2c-$(date +%y%m%d)"
MAX_JOBS=2

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=clang
export LLVM=1
export LLVM_IAS=1

cd "$ROOT_DIR"

echo "[1/9] Limpiando..."
rm -rf KernelSU KernelSU-Next 2>/dev/null
git checkout . 2>/dev/null
touch .scmversion

echo "[2/9] Clonando SUSFS..."
if [ ! -d "$SUSFS_DIR" ]; then
    git clone --depth=1 --branch=gki-android12-5.10 \
        https://gitlab.com/simonpunk/susfs4ksu.git "$SUSFS_DIR"
fi

echo "[3/9] Aplicando parches SUSFS al kernel..."
cp "$SUSFS_DIR/kernel_patches/fs/susfs.c" fs/susfs.c
cp "$SUSFS_DIR/kernel_patches/include/linux/susfs.h" include/linux/susfs.h
cp "$SUSFS_DIR/kernel_patches/include/linux/susfs_def.h" include/linux/susfs_def.h
patch -p1 -N -r /dev/null < "$SUSFS_DIR/kernel_patches/50_add_susfs_in_gki-android12-5.10.patch"

echo "[4/9] Clonando KernelSU (tiann)..."
git clone --depth=1 https://github.com/tiann/KernelSU.git KernelSU

echo "[5/9] Aplicando parche SUSFS para KSU..."
cd KernelSU
patch -p1 -N -r /dev/null < "$SUSFS_DIR/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch"
cd "$ROOT_DIR"

echo "[6/9] Integrando KSU en drivers/..."
ln -sf "$ROOT_DIR/KernelSU/kernel" drivers/kernelsu
grep -q "kernelsu" drivers/Makefile || echo "obj-\$(CONFIG_KSU) += kernelsu/" >> drivers/Makefile
grep -q "kernelsu/Kconfig" drivers/Kconfig || sed -i "/endmenu/i\source \"drivers/kernelsu/Kconfig\"" drivers/Kconfig

echo "[7/9] Configurando..."
make gki_defconfig
./scripts/kconfig/merge_config.sh -m -O . \
    arch/arm64/configs/gki_defconfig \
    arch/arm64/configs/hyperos_optimized.fragment \
    arch/arm64/configs/ksu.fragment
echo "CONFIG_LOCALVERSION=\"${BUILD_SUFFIX}\"" >> .config
make olddefconfig

grep -q "CONFIG_KSU=y" .config || echo "ERROR: CONFIG_KSU no activado"

echo "[8/9] Compilando..."
nice -n 19 make -j$MAX_JOBS

if [ ! -f arch/arm64/boot/Image ]; then
    echo "ERROR: Image no generado"
    exit 1
fi

echo "[9/9] AnyKernel3..."
mkdir -p "$OUTPUT_DIR"
cp arch/arm64/boot/Image "$OUTPUT_DIR/Image"

AK3_DIR="/tmp/anykernel3"
if [ ! -d "$AK3_DIR" ]; then
    git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "$AK3_DIR"
fi

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
echo ""
echo "=== COMPLETADO ==="
strings vmlinux 2>/dev/null | grep "Linux version" | head -1
ls -lh "$OUTPUT_DIR/"
) 2>&1 | tee "$LOG"

echo "Log completo: $LOG"
