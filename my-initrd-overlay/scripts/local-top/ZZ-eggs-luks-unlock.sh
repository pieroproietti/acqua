#!/bin/sh
# Questo è lo SCRIPT RUNTIME (in local-top) v19

set -e

exec > /tmp/unlock.log 2>&1 # <-- AGGIUNGI QUESTA RIGA

echo "EGGS: script (v19) in local-top partito."
echo "EGGS: Assumo che /dev sia popolato dal sistema principale..."

# PAUSA AGGIUNTIVA per dare tempo a udev di finire
echo "EGGS: Attesa extra per udev (10 secondi)..."
sleep 10

# Controlla se /dev esiste (debug)
ls /dev

# 1. Trova live media
echo "EGGS: Ricerca live media..."
mkdir -p /mnt/live-media
mkdir -p /mnt/ext4
LIVE_DEV=""
# Loop di ricerca più lungo
MAX_WAIT_DEV=20 
COUNT_DEV=0
while [ -z "$LIVE_DEV" ] && [ $COUNT_DEV -lt $MAX_WAIT_DEV ]; do
    echo "EGGS: Tento ricerca ($COUNT_DEV/$MAX_WAIT_DEV)..."
    for dev in /dev/sr* /dev/sd* /dev/vd* /dev/nvme*n*; do
        [ -b "$dev" ] || continue
        echo "EGGS: Provo $dev..."
        if mount -o ro "$dev" /mnt/live-media 2>/dev/null; then
            if [ -f /mnt/live-media/live/root.img ]; then
                echo "EGGS: Trovata live media su $dev"
                LIVE_DEV=$dev
                break 2 # Esci da entrambi i loop
            fi
            umount /mnt/live-media 2>/dev/null
        fi
    done
    sleep 1
    COUNT_DEV=$((COUNT_DEV+1))
done

if [ -z "$LIVE_DEV" ]; then
    echo "EGGS: ERRORE: Impossibile trovare live media dopo $MAX_WAIT_DEV sec."
    ls /dev
    exec /bin/sh
fi

ROOT_IMG_RO="/mnt/live-media/live/root.img"
ROOT_IMG="/tmp/root.img.rw"

# 2. Copia in RAM
echo "EGGS: Copia di root.img in RAM (/tmp)..."
cp "$ROOT_IMG_RO" "$ROOT_IMG"

# 3. Sblocca LUKS
echo "EGGS: In attesa della passphrase per sbloccare $ROOT_IMG..."
if ! cryptsetup open "$ROOT_IMG" live-root; then
    echo "EGGS: ERRORE: Sblocco LUKS fallito."
    rm "$ROOT_IMG"
    exec /bin/sh
fi
echo "EGGS: LUKS sbloccato. Attesa per /dev/mapper/live-root..."

# Loop di attesa per il device mapper
MAX_WAIT_MAP=10
COUNT_MAP=0
while [ ! -b /dev/mapper/live-root ] && [ $COUNT_MAP -lt $MAX_WAIT_MAP ]; do
    echo "EGGS: Aspetto /dev/mapper/live-root... ($COUNT_MAP/$MAX_WAIT_MAP)"
    sleep 1
    COUNT_MAP=$((COUNT_MAP+1))
    # Non chiamiamo udevadm settle qui, assumiamo che giri già
done

if [ ! -b /dev/mapper/live-root ]; then
    echo "EGGS: ERRORE: Device /dev/mapper/live-root non apparso dopo $MAX_WAIT_MAP sec."
    ls /dev/mapper
    cryptsetup close live-root || true
    rm "$ROOT_IMG" || true
    exec /bin/sh
fi
echo "EGGS: Device mapper pronto."

# 4. Monta l'ext4 (rw)
mount -t ext4 -o rw /dev/mapper/live-root /mnt/ext4

# 5. Monta lo squashfs sulla destinazione finale
echo "EGGS: Montaggio filesystem.squashfs su ${rootmnt}..."
mount -o loop /mnt/ext4/filesystem.squashfs "${rootmnt}"

# 6. Pulisci
umount /mnt/ext4
cryptsetup close live-root
rm "$ROOT_IMG"
umount /mnt/live-media

# 7. Passa il testimone
export ROOT_MOUNTED=true
echo "EGGS: Fatto. rootfs pronto, avvio del sistema."
exit 0