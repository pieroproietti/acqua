cryptsetup  e cryptsetup-initramfs sono già installati.

Ti mando il quadro ancora puù completo con il contenuto di my-init-overlay che esiste.


```
artisan@colibri:~/acqua$ sudo apt install cryptsetup  cryptsetup-initramfs 
[sudo] password for artisan: 
cryptsetup is already the newest version (2:2.7.5-2).
cryptsetup-initramfs is already the newest version (2:2.7.5-2).
cryptsetup-initramfs set to manually installed.
Summary:
  Upgrading: 0, Installing: 0, Removing: 0, Not Upgrading: 0
```

# 1 Struttura dirs

```
artisan@colibri:~/acqua$ ls 

final-initrd.img  initrd.img-6.12.48+deb13-amd64  my-initrd-overlay  process.sh  staging

artisan@colibri:~/acqua$ ls staging/

kernel  scripts

# 2 staging/scripts/live-premount

artisan@colibri:~/acqua$ ls 

```
artisan@colibri:~/acqua$ ls my-initrd-overlay/scripts/live-premount/ZZ-eggs-luks-unlock.sh 
my-initrd-overlay/scripts/live-premount/ZZ-eggs-luks-unlock.sh

# staging/scripts/live-premount/Z-eggs-luks-unlock.sh 
```
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
```

# 3 process.sh

```

#!/bin/bash



# Il tuo overlay con lo script di sblocco

OVERLAY_DIR="my-initrd-overlay"



# L'initramfs di base creato dal tuo tool

BASE_INITRD="initrd.img-6.12.48+deb13-amd64"



# L'initramfs finale per la ISO

FINAL_INITRD="final-initrd.img"



# 1. Crea una directory di staging pulita

STAGING=./staging

rm -rf $STAGING

mkdir -p $STAGING

cd $STAGING



# 2. Estrai l'initramfs di base

#echo "EGGS: Estraggo initramfs di base..."

#gzip -d < "../${BASE_INITRD}" | cpio -idm

cat "../${BASE_INITRD}" | cpio -idm



# 3. "Appiccica" i tuoi file overlay

# Questo è il momento chiave! Copi i tuoi file sopra quelli esistenti.

# Il tuo script finirà in /tmp/staging/scripts/local-top/ZZ-eggs-luks-unlock.sh

echo "EGGS: Applico overlay di sblocco..."

cp -R "../${OVERLAY_DIR}/"* .



# 4. Ricrea l'archivio finale

echo "EGGS: Ricomprimo initramfs finale..."

find . | cpio -o -H newc | gzip -c > "../${FINAL_INITRD}"



# 5. Pulisci

cd ..

# rm -rf $STAGING

```



# 4. codice di creazione initramfs in eggs

```

/**

 * initrdDebian

 */

export async function initrdDebian(this: Ovary, verbose = false) {

    Utils.warning(`creating ${this.initrd} using mkinitramfs on (ISO)/live`)



    const prefix = this.settings.config.snapshot_prefix

    const dest = `${this.settings.iso_work}live/${path.basename(this.initrd)}`

    const log = `> ${this.settings.iso_work}${prefix}mkinitramfs.log.txt 2>&1`

    const cmd = `mkinitramfs -o ${dest} ${this.kernel} ${log}`

    // console.log(cmd)

    await exec(cmd, this.echo)

}
```

# 4. log di creazione di initrd.img-6.12.48+deb13-amd64 da eggs

In allegato
