#!/bin/bash


# --- IMPOSTAZIONI ---
OVERLAY_DIR="my-initrd-overlay"
BASE_INITRD="/home/eggs/iso/live/initrd.img-6.12.48+deb13-amd64"
FINAL_INITRD="final-initrd.img"
STAGING=./staging

# PERCORSO AL SISTEMA DI ORIGINE (CHROOT) DA CUI COPIARE I BINARI
# CAMBIA QUESTO con il percorso reale
# DATO eggs replica il sistema reale, 
# va bene così
CHROOT_PATH="/" 

# --- SCRIPT ---

# 1. Crea una directory di staging pulita
rm -rf $STAGING
mkdir -p $STAGING
cd $STAGING

# 2. Estrai l'initramfs di base
echo "EGGS: Estraggo initramfs di base..."
cat "${BASE_INITRD}" | cpio -idm

# ==================================================================
# 3. FASE DI INIEZIONE MANUALE (IL FIX)
#    Copiamo i file necessari dal chroot allo staging
# ==================================================================
echo "EGGS: Inietto manualmente i binari di cryptsetup..."

# Crea le directory necessarie dentro lo staging
mkdir -p ./sbin
mkdir -p ./lib/x86_64-linux-gnu  # Adatta se non è amd64
mkdir -p ./lib64

# Copia i binari
cp "${CHROOT_PATH}/sbin/cryptsetup" ./sbin/
cp "${CHROOT_PATH}/sbin/losetup"    ./sbin/

# Copia le librerie (LDD) - FONDAMENTALE
echo "EGGS: Inietto le librerie..."
ldd "${CHROOT_PATH}/sbin/cryptsetup" | grep "=> /" | awk '{print $3}' | xargs -I {} cp -v {} ./lib/x86_64-linux-gnu/

# Copia il linker (sempre necessario)
cp "${CHROOT_PATH}/lib64/ld-linux-x86-64.so.2" ./lib64/
# ==================================================================

# 4. "Appiccica" i tuoi file overlay (lo script di sblocco)
echo "EGGS: Applico overlay di sblocco (lo script)..."
cp -R "../${OVERLAY_DIR}/"* .

# 5. Ricrea l'archivio finale
echo "EGGS: Ricomprimo initramfs finale..."
find . | cpio -o -H newc > "../${FINAL_INITRD}"

# 6. Pulisci
cd ..
# rm -rf $STAGING

echo "EGGS: Fatto! ${FINAL_INITRD} è pronto."
