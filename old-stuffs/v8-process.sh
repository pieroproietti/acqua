#!/bin/bash
# v8-process.sh - unmkinitramfs (extract) + dummy conf (fix) + mkinitramfs (repack)
echo "v8-process.sh - Metodo unmkinitramfs + mkinitramfs (con fix)"

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

# Verifica che 'unmkinitramfs' abbia creato 'main'
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
# Rimettilo in 'live-premount', che è la sua casa logica
# (Assicurati che my-initrd-overlay/scripts/live-premount esista)
cp -R "${OVERLAY_DIR}/"* "${STAGING}/main/"

# 5. IL FIX: Crea il file di configurazione mancante
echo "EGGS: Creo initramfs.conf fittizio in ${STAGING}/main/..."
# Creiamo un file minimo per soddisfare mkinitramfs
# e gli diciamo di NON COMPRIMERE (importante!)
echo 'COMPRESS=uncompressed' > "${STAGING}/main/initramfs.conf"

# 6. Ricrea l'archivio finale (NON COMPRESSO)
echo "EGGS: Ricreo initramfs finale (non compresso) da ${STAGING}/main..."
# -d = usa una directory esistente
# -o = file di output
mkinitramfs -d "${STAGING}/main" -o "../${FINAL_INITRD}"

# 7. Pulisci
# rm -rf $STAGING

echo "EGGS: Fatto! ${FINAL_INITRD} è pronto."