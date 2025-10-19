#!/bin/bash
# v6-process.sh - Il metodo "Frankenstein" (Append)
echo "v6-process.sh - Metodo Frankenstein (Append)"

# --- IMPOSTAZIONI ---
OVERLAY_DIR="my-initrd-overlay"
BASE_INITRD="/home/eggs/iso/live/initrd.img-6.12.48+deb13-amd64" # Il 70MB (funzionante)
FINAL_INITRD="final-initrd.img"
STAGING_CRYPT=./staging_crypt # Staging solo per i nostri file
CRYPT_CPIO="crypt-overlay.cpio" # Il nostro archivio da 14MB
CHROOT_PATH="/"

# --- SCRIPT ---

# 1. Crea una directory di staging pulita (solo per i file crypt)
rm -rf $STAGING_CRYPT
mkdir -p $STAGING_CRYPT
cd $STAGING_CRYPT

# 2. FASE INIEZIONE MANUALE (CRYPTSETUP)
echo "EGGS: Preparo i file di cryptsetup..."
mkdir -p ./sbin
mkdir -p ./lib/x86_64-linux-gnu
mkdir -p ./lib64

cp "${CHROOT_PATH}/sbin/cryptsetup" ./sbin/
cp "${CHROOT_PATH}/sbin/losetup"    ./sbin/

echo "EGGS: Preparo le librerie (cryptsetup)..."
ldd "${CHROOT_PATH}/sbin/cryptsetup" | grep "=> /" | awk '{print $3}' | xargs -I {} cp -v {} ./lib/x86_64-linux-gnu/
cp "${CHROOT_PATH}/lib64/ld-linux-x86-64.so.2" ./lib64/

# 3. "Appiccica" i tuoi file overlay (lo script di sblocco)
echo "EGGS: Preparo l'overlay di sblocco (lo script)..."
# Copiamo la *struttura* di my-initrd-overlay
cp -R "../${OVERLAY_DIR}/"* .

# 4. Crea l'archivio CPIO (NON COMPRESSO) dei SOLI file crypt
echo "EGGS: Creo l'archivio cpio dei soli file di sblocco..."
find . | cpio -o -H newc > "../${CRYPT_CPIO}"
cd ..

# 5. IL COLPO FINALE: Concatena i due archivi
echo "EGGS: Creo l'initrd 'Frankenstein' finale..."
cat "${BASE_INITRD}" "${CRYPT_CPIO}" > "${FINAL_INITRD}"

# 6. Pulisci
rm -rf $STAGING_CRYPT
rm $CRYPT_CPIO

echo "EGGS: Fatto! ${FINAL_INITRD} è pronto (Dimensione attesa: ~84MB)."