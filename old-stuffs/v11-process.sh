#!/bin/bash
# v11-builder.sh - Costruisce un initrd da zero (CON MODULI KERNEL)
echo "v11-builder.sh - Costruzione da zero, con moduli kernel..."

# --- IMPOSTAZIONI ---
OVERLAY_DIR="my-initrd-overlay"                 # Contiene lo script in scripts/live-premount/
FINAL_INITRD="luks-initrd.img-6.12.48+deb13-amd64"
STAGING=./staging_v11                           # Directory di lavoro pulita
CHROOT_PATH="/"                                 # Fonte dei file
KERNEL_VERSION="6.12.48+deb13-amd64"             # Assicurati che sia corretto!

# --- SCRIPT ---

# 1. Crea una directory di staging pulita
rm -rf $STAGING
mkdir -p $STAGING
cd $STAGING

echo "EGGS: Staging pulito creato in $STAGING"

# ==================================================================
# 2. FASE INIEZIONE MANUALE (CRYPTSETUP)
# ==================================================================
echo "EGGS: Inietto manualmente i binari di cryptsetup..."
mkdir -p ./sbin
mkdir -p ./lib/x86_64-linux-gnu
mkdir -p ./lib64
cp "${CHROOT_PATH}/sbin/cryptsetup" ./sbin/
cp "${CHROOT_PATH}/sbin/losetup"    ./sbin/

echo "EGGS: Inietto le librerie (cryptsetup)..."
ldd "${CHROOT_PATH}/sbin/cryptsetup" | grep "=> /" | awk '{print $3}' | xargs -I {} cp -v {} ./lib/x86_64-linux-gnu/
cp "${CHROOT_PATH}/lib64/ld-linux-x86-64.so.2" ./lib64/

# ==================================================================
# 3. FASE INIEZIONE MANUALE (LIVE-BOOT)
# ==================================================================
echo "EGGS: Inietto manualmente i file di live-boot..."
mkdir -p ./lib/live-boot
mkdir -p ./scripts
cp -R -v "${CHROOT_PATH}/usr/lib/live/boot"/* ./lib/live-boot/
cp -v "${CHROOT_PATH}/usr/share/initramfs-tools/scripts/live" ./scripts/

# ==================================================================
# 4. FASE INIEZIONE MANUALE (MODULI KERNEL ESSENZIALI)
# ==================================================================
echo "EGGS: Inietto i moduli kernel per ${KERNEL_VERSION}..."
MODULES_PATH="lib/modules/${KERNEL_VERSION}"
mkdir -p "./${MODULES_PATH}/kernel/drivers/md"
mkdir -p "./${MODULES_PATH}/kernel/drivers/block"
mkdir -p "./${MODULES_PATH}/kernel/fs/squashfs"
mkdir -p "./${MODULES_PATH}/kernel/fs/ext4"
mkdir -p "./${MODULES_PATH}/kernel/fs/iso9660"

# Copia i moduli
cp -v "${CHROOT_PATH}/${MODULES_PATH}/kernel/drivers/md/dm-crypt.ko"  "./${MODULES_PATH}/kernel/drivers/md/"
cp -v "${CHROOT_PATH}/${MODULES_PATH}/kernel/drivers/md/dm-mod.ko"    "./${MODULES_PATH}/kernel/drivers/md/"
cp -v "${CHROOT_PATH}/${MODULES_PATH}/kernel/drivers/block/loop.ko" "./${MODULES_PATH}/kernel/drivers/block/"
cp -v "${CHROOT_PATH}/${MODULES_PATH}/kernel/fs/squashfs/squashfs.ko" "./${MODULES_PATH}/kernel/fs/squashfs/"
cp -v "${CHROOT_PATH}/${MODULES_PATH}/kernel/fs/ext4/ext4.ko"       "./${MODULES_PATH}/kernel/fs/ext4/"
cp -v "${CHROOT_PATH}/${MODULES_PATH}/kernel/fs/iso9660/iso9660.ko" "./${MODULES_PATH}/kernel/fs/iso9660/"
# (Potrebbero mancare dipendenze (es. JBD2 per ext4), ma proviamo con l'essenziale)

# ==================================================================
# 5. FASE INIEZIONE MANUALE (FILE ESSENZIALI)
# ==================================================================
echo "EGGS: Inietto i file di base (ash, cpio, mount...)"
mkdir -p ./bin
cp "${CHROOT_PATH}/bin/busybox" ./bin/
cp "${CHROOT_PATH}/bin/mount"   ./bin/
cp "${CHROOT_PATH}/bin/umount"  ./bin/
ln -s ./bin/busybox ./bin/sh

mkdir -p ./
cat > ./init << EOF
#!/bin/sh
echo "EGGS: init (v11) partito."
/scripts/live
exec /bin/sh
EOF
chmod +x ./init

# ==================================================================
# 6. "Appiccica" i tuoi file overlay (lo script di sblocco)
# ==================================================================
echo "EGGS: Applico overlay di sblocco (in scripts/live-premount)..."
# Assicurati che il tuo overlay sia in 'scripts/live-premount'
cp -R "../${OVERLAY_DIR}/"* .

# 7. Ricrea l'archivio finale (NON COMPRESSO)
echo "EGGS: Ricreo initramfs finale (non compresso)..."
find . | cpio -o -H newc > "../${FINAL_INITRD}"

# 8. Pulisci
cd ..
# rm -rf $STAGING

echo "EGGS: Fatto! ${FINAL_INITRD} è pronto."