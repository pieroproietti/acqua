#!/bin/bash
# v17-process.sh - Il "Frankenstein" Completo (cryptsetup + udev)
echo "v17-process.sh - Metodo Frankenstein (Append) con UDEV"

# --- IMPOSTAZIONI ---
OVERLAY_DIR="my-initrd-overlay"  # Assicurati che lo script sia in scripts/local-top/
BASE_INITRD="/home/eggs/iso/live/initrd.img-6.12.48+deb13-amd64" # Il 70MB (funzionante)
FINAL_INITRD="luks-initrd.img-6.12.48+deb13-amd64" # Il nostro ~84MB
STAGING_CRYPT=./staging_crypt # Staging solo per i nostri file
CRYPT_CPIO="crypt-overlay.cpio" # Il nostro archivio
CHROOT_PATH="/"

# --- SCRIPT ---

# 1. Crea una directory di staging pulita (solo per i file crypt)
rm -rf $STAGING_CRYPT
mkdir -p $STAGING_CRYPT
cd $STAGING_CRYPT

# ==================================================================
# 2. FASE INIEZIONE MANUALE (CRYPTSETUP)
# ==================================================================
echo "EGGS: Preparo i file di cryptsetup..."
mkdir -p ./sbin
mkdir -p ./lib/x86_64-linux-gnu
mkdir -p ./lib64

cp "${CHROOT_PATH}/sbin/cryptsetup" ./sbin/
cp "${CHROOT_PATH}/sbin/losetup"    ./sbin/

echo "EGGS: Preparo le librerie (cryptsetup)..."
ldd "${CHROOT_PATH}/sbin/cryptsetup" | grep "=> /" | awk '{print $3}' | xargs -I {} cp -v {} ./lib/x86_64-linux-gnu/
cp "${CHROOT_PATH}/lib64/ld-linux-x86-64.so.2" ./lib64/

# ==================================================================
# 3. FASE INIEZIONE MANUALE (UDEV) - IL PEZZO NUOVO
# ==================================================================
echo "EGGS: Inietto UDEV (systemd-udevd e udevadm)..."
mkdir -p ./lib/udev
cp -R "${CHROOT_PATH}/lib/udev/rules.d" ./lib/udev/

# Percorsi corretti (trovati con v15):
cp "${CHROOT_PATH}/lib/systemd/systemd-udevd" ./sbin/udevd
cp "${CHROOT_PATH}/usr/bin/udevadm"           ./sbin/udevadm

echo "EGGS: Inietto le librerie (udev)..."
ldd "${CHROOT_PATH}/lib/systemd/systemd-udevd" | grep "=> /" | awk '{print $3}' | xargs -I {} cp -v {} ./lib/x86_64-linux-gnu/
ldd "${CHROOT_PATH}/usr/bin/udevadm" | grep "=> /" | awk '{print $3}' | xargs -I {} cp -v {} ./lib/x86_64-linux-gnu/
# ==================================================================

# 4. "Appiccica" i tuoi file overlay (lo script di sblocco)
echo "EGGS: Preparo l'overlay di sblocco (lo script)..."
# Assicurati che il tuo overlay sia in 'scripts/local-top/'
cp -R "../${OVERLAY_DIR}/"* .

# 5. Crea l'archivio CPIO (NON COMPRESSO)
echo "EGGS: Creo l'archivio cpio dei soli file di sblocco..."
find . | cpio -o -H newc > "../${CRYPT_CPIO}"
cd ..

# 6. IL COLPO FINALE: Concatena i due archivi
echo "EGGS: Creo l'initrd 'Frankenstein' finale..."
cat "${BASE_INITRD}" "${CRYPT_CPIO}" > "${FINAL_INITRD}"

# 7. Pulisci
rm -rf $STAGING_CRYPT
rm $CRYPT_CPIO

echo "EGGS: Fatto! ${FINAL_INITRD} è pronto (Dimensione attesa: ~92MB)."