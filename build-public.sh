#!/bin/bash
set -e

echo "============================================"
echo " Templar Kernel GKI 5.10 - Public Build"
echo " Generic GKI - works on any device"
echo "============================================"

ROOT_DIR="/home/sarkot/templar-kernel-public"
OUTPUT_DIR="/home/sarkot/kernel-output-public"
MAX_JOBS=2

TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')

echo "RAM: ${TOTAL_RAM}MB | Swap: ${SWAP_TOTAL}MB | Jobs: $MAX_JOBS"

if [ "$TOTAL_RAM" -lt 4096 ]; then
    echo "ERROR: At least 4GB RAM required."
    exit 1
fi

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=clang
export LLVM=1
export LLVM_IAS=1

mkdir -p "$OUTPUT_DIR"

cd "$ROOT_DIR"

echo ""
echo "[1/4] Configuring kernel..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang LLVM=1 LLVM_IAS=1 gki_defconfig 2>&1
./scripts/kconfig/merge_config.sh -m -O . \
    arch/arm64/configs/gki_defconfig \
    arch/arm64/configs/gki_safe_optimized.fragment 2>&1
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang LLVM=1 LLVM_IAS=1 olddefconfig 2>&1

echo ""
echo "[2/4] Building kernel..."
nice -n 19 make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang LLVM=1 LLVM_IAS=1 -j$MAX_JOBS 2>&1

echo ""
echo "[3/4] Verifying build..."
if [ ! -f "arch/arm64/boot/Image" ]; then
    echo "ERROR: Image not found!"
    exit 1
fi

KERNEL_VERSION=$(strings vmlinux | grep "Linux version" | head -1)
echo "Kernel: $KERNEL_VERSION"

cp arch/arm64/boot/Image "$OUTPUT_DIR/Image"
echo "Image -> $OUTPUT_DIR/Image"

echo ""
echo "[4/4] Creating AnyKernel3 zip..."
AK3_DIR="/home/sarkot/anykernel3"
if [ ! -d "$AK3_DIR" ]; then
    git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "$AK3_DIR" 2>&1
fi

if [ -d "$AK3_DIR" ]; then
    cat > "$AK3_DIR/anykernel.sh" << 'AK3'
properties() { '
kernel.string=Templar Kernel GKI 5.10 - Public Build
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

BLOCK=boot;
IS_SLOT_DEVICE=auto;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

. tools/ak3-core.sh;

dump_boot;
write_boot;
AK3

    cp "$OUTPUT_DIR/Image" "$AK3_DIR/Image"
    cd "$AK3_DIR"
    rm -f "$OUTPUT_DIR/TemplarKernel-GKI5.10-Public.zip"
    zip -r9 "$OUTPUT_DIR/TemplarKernel-GKI5.10-Public.zip" * \
        -x ".git/*" "README.md" "LICENSE" 2>&1
    echo "Zip: $OUTPUT_DIR/TemplarKernel-GKI5.10-Public.zip"
fi

echo ""
echo "Done! Check $OUTPUT_DIR/"
ls -lh "$OUTPUT_DIR/"
echo ""
echo "WARNING: Generic GKI kernel. No DTBs or vendor modules included."
echo "Only compatible with GKI 5.10 devices. Backup your boot.img first."
