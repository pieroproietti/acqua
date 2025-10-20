#!/bin/bash
set x

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo or as root."
  exit 1
fi

echo "Running as root..."
./v6-process.sh
cp isolinux.cfg /home/eggs/iso/isolinux
cp luks-initrd.img-6.12.48+deb13-amd64 /home/eggs/iso/live/
/home/eggs/ovarium/mkisofs 
eggs export iso --clean



