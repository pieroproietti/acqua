#!/bin/bash
# v15-builder.sh - Costruzione da zero (con percorsi udev corretti)
echo "v15-builder.sh - Costruzione da zero, con percorsi udev corretti..."

# --- IMPOSTAZIONI ---
OVERLAY_DIR="my-initrd-overlay"                 # Contiene lo script in scripts/live-premount/
FINAL_INITRD="luks-initrd.img-6.12.48+deb13-amd64"
STAGING=./staging_v15                           # Directory di lavoro pulita
CHROOT_PATH="/"                                 # Fonte dei file

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
# 4. FASE INIEZIONE MANUALE (FILE ESSENZIALI e INIT CORRETTO)
# ==================================================================
echo "EGGS: Inietto i file di base e l'init script..."
mkdir -p ./bin
cp "${CHROOT_PATH}/bin/busybox" ./bin/
cp "${CHROOT_PATH}/bin/mount"   ./bin/
cp "${CHROOT_PATH}/bin/umount"  ./bin/
ln -s ./bin/busybox ./bin/sh

# === IL FIX (v15) ===
# Copiamo i file di UDEV dai percorsi REALI che hai trovato
echo "EGGS: Inietto UDEV (systemd-udevd e udevadm)..."
mkdir -p ./lib/udev
cp -R "${CHROOT_PATH}/lib/udev/rules.d" ./lib/udev/

# Percorsi corretti:
cp "${CHROOT_PATH}/lib/systemd/systemd-udevd" ./sbin/udevd
cp "${CHROOT_PATH}/usr/bin/udevadm"           ./sbin/udevadm

# Copiamo le librerie mancanti per udev/systemd
ldd "${CHROOT_PATH}/lib/systemd/systemd-udevd" | grep "=> /" | awk '{print $3}' | xargs -I {} cp -v {} ./lib/x86_64-linux-gnu/
ldd "${CHROOT_PATH}/usr/bin/udevadm" | grep "=> /" | awk '{print $3}' | xargs -I {} cp -v {} ./lib/x86_64-linux-gnu/
# === FINE FIX ===

# Crea l'entrypoint 'init' che prepara il sistema
mkdir -p ./
cat > ./init << EOF
#!/bin/sh

echo "EGGS: init (v15) partito."

# 1. Monta i filesystem virtuali
echo "EGGS: Montaggio /proc, /sys, /run..."
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t tmpfs tmpfs /run

# 2. Avvia UDEV per popolare /dev
echo "EGGS: Avvio udev..."
/sbin/udevd --daemon
/sbin/udevadm trigger
/sbin/udevadm settle

echo "EGGS: /dev popolato. Avvio /scripts/live..."

# 3. Avvia live-boot (che ora troverà /dev/sr0 e /dev/mapper)
/scripts/live

# Se fallisce, ci dà una shell
echo "EGGS: live-boot fallito. Avvio shell di emergenza."
exec /bin/sh
EOF

chmod +x ./init

# ==================================================================
# 5. "Appiccica" i tuoi file overlay (lo script di sblocco)
# ==================================================================
echo "EGGS: Applico overlay di sblocco (in scripts/live-premount)..."
cp -R "../${OVERLAY_DIR}/"* .

# 6. Ricrea l'archivio finale (NON COMPRESSO)
echo "EGGS: Ricreo initramfs finale (non compresso)..."
find . | cpio -o -H newc > "../${FINAL_INITRD}"

# 7. Pulisci
cd ..
# rm -rf $STAGING

echo "EGGS: Fatto! ${FINAL_INITRD} è pronto."