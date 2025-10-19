#!/bin/bash
# v10-builder.sh - Costruisce un initrd da zero
echo "v10-builder.sh - Costruzione da zero..."

# --- IMPOSTAZIONI ---
OVERLAY_DIR="my-initrd-overlay"                 # Contiene il tuo script di sblocco
FINAL_INITRD="luks-initrd.img-6.12.48+deb13-amd64" # Il nostro file finale
STAGING=./staging_v10                           # Directory di lavoro pulita
CHROOT_PATH="/"                                 # Fonte dei file (il tuo sistema)

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

# Copia gli script "runtime" (quelli che girano al boot)
cp -R -v "${CHROOT_PATH}/usr/lib/live/boot"/* ./lib/live-boot/
cp -v "${CHROOT_PATH}/usr/share/initramfs-tools/scripts/live" ./scripts/

# ==================================================================
# 4. FASE INIEZIONE MANUALE (FILE ESSENZIALI)
# ==================================================================
echo "EGGS: Inietto i file di base (ash, cpio, mount...)"
# Abbiamo bisogno di una shell minima e dei comandi di base
mkdir -p ./bin
cp "${CHROOT_PATH}/bin/busybox" ./bin/
cp "${CHROOT_PATH}/bin/mount"   ./bin/
cp "${CHROOT_PATH}/bin/umount"  ./bin/

# Busybox crea i link simbolici (ash, sh, ls, cat, etc.)
# Se non li hai, creiamo almeno 'sh'
ln -s ./bin/busybox ./bin/sh

# Crea l'entrypoint 'init' che lancia 'live-boot'
mkdir -p ./
cat > ./init << EOF
#!/bin/sh
echo "EGGS: init (da zero) partito."
/scripts/live
# Se live-boot fallisce, ci dà una shell
exec /bin/sh
EOF

chmod +x ./init

# ==================================================================
# 5. "Appiccica" i tuoi file overlay (lo script di sblocco)
# ==================================================================
echo "EGGS: Applico overlay di sblocco (lo script)..."
# Assicurati che il tuo overlay sia in 'scripts/local-top'
# Esempio: my-initrd-overlay/scripts/local-top/ZZ-eggs-luks-unlock.sh
cp -R "../${OVERLAY_DIR}/"* .

# 6. Ricrea l'archivio finale (NON COMPRESSO)
echo "EGGS: Ricreo initramfs finale (non compresso) da $STAGING..."
find . | cpio -o -H newc > "../${FINAL_INITRD}"

# 7. Pulisci
cd ..
# rm -rf $STAGING

echo "EGGS: Fatto! ${FINAL_INITRD} è pronto."