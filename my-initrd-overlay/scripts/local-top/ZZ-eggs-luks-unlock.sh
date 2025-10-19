#!/bin/sh
# Questo è lo SCRIPT RUNTIME
# Eseguito da live-boot al BOOT della ISO

set -e

echo "EGGS: Avvio sblocco root.img..."

mkdir -p /mnt/live-media
mkdir -p /mnt/ext4

# 1. Trova live media
# (live-boot potrebbe averla già montata su /run/live/medium,
# ma farlo di nuovo è più robusto)
for dev in /dev/sr* /dev/sd* /dev/vd* /dev/nvme*n*; do
    [ -b "$dev" ] || continue
    if mount -o ro "$dev" /mnt/live-media 2>/dev/null; then
        if [ -f /mnt/live-media/live/root.img ]; then
            echo "EGGS: Trovata live media su $dev"
            break
        fi
        umount /mnt/live-media 2>/dev/null
    fi
done

if [ ! -f /mnt/live-media/live/root.img ]; then
    echo "EGGS: ERRORE: Impossibile trovare /live/root.img"
    exec /bin/sh
fi

ROOT_IMG_RO="/mnt/live-media/live/root.img"
ROOT_IMG="/tmp/root.img.rw"

# 2. Copia in RAM (per pulizia ext4)
echo "EGGS: Copia di root.img in RAM (/tmp)..."
cp "$ROOT_IMG_RO" "$ROOT_IMG"

# 3. Sblocca LUKS
echo "EGGS: In attesa della passphrase per sbloccare $ROOT_IMG..."
if ! cryptsetup open "$ROOT_IMG" live-root; then
    echo "EGGS: ERRORE: Sblocco LUKS fallito."
    rm "$ROOT_IMG"
    exec /bin/sh
fi

# 4. Monta l'ext4 (rw) per la pulizia
mount -t ext4 -o rw /dev/mapper/live-root /mnt/ext4

# 5. Monta lo squashfs sulla destinazione finale
#    che live-boot si aspetta. La variabile $rootmnt
#    è fornita da live-boot stesso (di solito è /root).
echo "EGGS: Montaggio filesystem.squashfs su ${rootmnt}..."
mount -o loop /mnt/ext4/filesystem.squashfs "${rootmnt}"

# 6. Pulisci (lascia montato solo il rootfs finale)
umount /mnt/ext4
cryptsetup close live-root
rm "$ROOT_IMG"
umount /mnt/live-media

# 7. IL COLPO FINALE: Passa il testimone!
#    Diciamo a live-boot che il rootfs è PRONTO
#    e che deve saltare la sua logica di ricerca.
export ROOT_MOUNTED=true

echo "EGGS: Fatto. rootfs pronto, avvio del sistema."
exit 0
