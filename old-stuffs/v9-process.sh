#!/bin/bash
# v9-process.sh - unmkinitramfs (extract) + mkinitramfs (repack)
# FIX: Aggiunto MODULES=list a initramfs.conf
echo "v9-process.sh - Metodo unmkinitramfs + mkinitramfs (con fix MODULES=list)"

# --- IMPOSTAZIONI ---
OVERLAY_DIR="my-initrd-overlay"
BASE_INITRD="/home/eggs/iso/live/initrd.img-6.12.48+deb13-amd64"
FINAL_INITRD="luks-initrd.img-6.12.48+deb13-amd64"
STAGING=./staging
CHROOT_PATH="/"

# --- SCRIPT ---

# 1. Crea una directory di staging pulita
rm -rf $STAGING
mkdir -p $STAGING

# 2. Estrai l'initramfs 'Frankenstein' con unmkinitramfs
echo "EGGS: Estraggo initramfs 'Frankenstein' con unmkinitramfs..."
cd $STAGING
unmkinitramfs "${BASE_INITRD}" .
cd .. 

# 3. FASE INIEZIONE MANUALE (CRYPTSETUP)
echo "EGGS: Inietto manualmente i binari di cryptsetup..."

if [ ! -d "${STAGING}/main" ]; then
    echo "ERRORE: unmkinitramfs non ha creato la directory 'main'. Esco."
    exit 1
fi

mkdir -p "${STAGING}/main/sbin"
mkdir -p "${STAGING}/main/lib/x86_64-linux-gnu"
mkdir -p "${STAGING}/main/lib64"
cp "${CHROOT_PATH}/sbin/cryptsetup" "${STAGING}/main/sbin/"
cp "${CHROOT_PATH}/sbin/losetup"    "${STAGING}/main/sbin/"

echo "EGGS: Inietto le librerie (cryptsetup)..."
ldd "${CHROOT_PATH}/sbin/cryptsetup" | grep "=> /" | awk '{print $3}' | xargs -I {} cp -v {} "${STAGING}/main/lib/x86_64-linux-gnu/"
cp "${CHROOT_PATH}/lib64/ld-linux-x86-64.so.2" "${STAGING}/main/lib64/"

# 4. "Appiccica" i tuoi file overlay (lo script di sblocco)
echo "EGGS: Applico overlay di sblocco (lo script)..."
cp -R "${OVERLAY_DIR}/"* "${STAGING}/main/"

# 5. IL FIX: Crea il file di configurazione mancante (MIGLIORATO)
echo "EGGS: Creo initramfs.conf fittizio in ${STAGING}/main/..."
cat > "${STAGING}/main/initramfs.conf" << EOF
COMPRESS=uncompressed
MODULES=list
EOF

# 6. Ricrea l'archivio finale (NON COMPRESSO)
echo "EGGS: Ricreo initramfs finale (non compresso) da ${STAGING}/main..."
mkinitramfs -d "${STAGING}/main" -o "../${FINAL_INITRD}"

# 7. Pulisci
# rm -rf $STAGING

echo "EGGS: Fatto! ${FINAL_INITRD} è pronto."