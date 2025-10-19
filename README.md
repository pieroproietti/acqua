# acqua

This is an attempt to create a working initramfs—one that boots the filesystem.squashfs contained on the ISO in `/live/root.img`— for the live system created by penguins-eggs with option `--fullcrypt`.

I have done many tests and testing is quite fast. Just copy the created `luks-initrd.img` to `/home/eggs/iso/live`, then when booting the ISO, replace `initrd.img` with `luls-initrd.img` and start the test.

I have done many tests with the help of gemini. 

They are contained in old-stuffs.

