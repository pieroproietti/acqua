#!/bin/bash
# v7-process.sh - Metodo "unmkinitramfs" e "mkinitramfs"
echo "v7-process.sh - Metodo di estrazione/ricostruzione"

# --- IMPOSTAZIONI ---
OVERLAY_DIR="my-initrd-overlay"
BASE_INITRD="/home/eggs/iso/live/initrd.img-6.12.48+deb13-amd64" # Il 70MB
FINAL_INITRD="luks-initrd.img-6.12.48+deb13-amd64"
STAGING=./staging
CHROOT_PATH="/"

# --- SCRIPT ---

# 1. Crea una directory di staging pulita
rm -rf $STAGING
mkdir -p $STAGING

# 2. Estrai l'initramfs 'Frankenstein' con unmkinitramfs
echo "EGGS: Estraggo initramfs 'Frankenstein' con unmkinitramfs..."
# unmkinitramfs estrae in una sottodirectory (es. main/)
# Dobbiamo entrare nello staging PRIMA di eseguire unmkinitramfs
cd $STAGING
# tolto il . ora è un path assoluto
unmkinitramfs "${BASE_INITRD}" .
cd .. 

# 3. FASE INIEZIONE MANUALE (CRYPTSETUP)
#    Ora iniettiamo i file nella directory 'main' creata da unmkinitramfs
echo "EGGS: Inietto manualmente i binari di cryptsetup..."
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

# 5. Ricrea l'archivio finale (NON COMPRESSO)
#    Usiamo mkinitramfs per re-impacchettare la directory di staging
echo "EGGS: Ricreo initramfs finale (non compresso) da ${STAGING}/main..."
# -d = usa una directory esistente
# -o = file di output
mkinitramfs -d "${STAGING}/main" -o "../${FINAL_INITRD}"

# 6. Pulisci
# rm -rf $STAGING

echo "EGGS: Fatto! ${FINAL_INITRD} è pronto."