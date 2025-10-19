#!/bin/bash
echo "v4-process"

# --- IMPOSTAZIONI ---
OVERLAY_DIR="my-initrd-overlay"
BASE_INITRD="/home/eggs/iso/live/initrd.img-6.12.48+deb13-amd64"
FINAL_INITRD="final-initrd.img"
STAGING=./staging

# PERCORSO AL SISTEMA DI ORIGINE (CHROOT)
CHROOT_PATH="/" 

# --- SCRIPT ---

# 1. Crea una directory di staging pulita
rm -rf $STAGING
mkdir -p $STAGING
cd $STAGING

# 2. Estrai l'initramfs di base
echo "EGGS: Estraggo initramfs di base (non compresso)..."
cat "${BASE_INITRD}" | cpio -idm

# ==================================================================
# 3. FASE INIEZIONE MANUALE (CRYPTSETUP)
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
# 4. FASE INIEZIONE MANUALE (LIVE-BOOT)
# ==================================================================
echo "EGGS: Inietto manualmente i file di live-boot..."

# Copia gli script di avvio (quelli che abbiamo trovato in v3)
mkdir -p ./lib/live-boot
cp -R -v "${CHROOT_PATH}/usr/lib/live/boot"/* ./lib/live-boot/

# Copia i "cervelli" di initramfs-tools (quelli appena trovati)
mkdir -p ./hooks
mkdir -p ./scripts
cp -v "${CHROOT_PATH}/usr/share/initramfs-tools/hooks/live"   ./hooks/
cp -v "${CHROOT_PATH}/usr/share/initramfs-tools/scripts/live" ./scripts/

# ==================================================================
# 5. "Appiccica" i tuoi file overlay (lo script di sblocco)
# ==================================================================
echo "EGGS: Applico overlay di sblocco (lo script)..."
cp -R "../${OVERLAY_DIR}/"* .

# 6. Ricrea l'archivio finale (NON COMPRESSO)
echo "EGGS: Ricreo initramfs finale (non compresso)..."
find . | cpio -o -H newc > "../${FINAL_INITRD}"

# 7. Pulisci
cd ..
# rm -rf $STAGING

echo "EGGS: Fatto! ${FINAL_INITRD} è pronto."