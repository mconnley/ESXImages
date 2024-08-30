#!/bin/bash

umount /tmp/imagebuilds/esxi_build_cdrom_mount -q
rm -f ImageBuildOnly-*
rm -f /tmp/download.zip
rm -rf /tmp/certs
rm -rf /tmp/imagebuilds/


mkdir /tmp/imagebuilds/
pwsh ./BuildESXiImage.ps1 "$1"
mkdir /tmp/imagebuilds/esxi_build_cdrom_mount
mkdir /tmp/imagebuilds/esxi_files
mount -t iso9660 -o loop,ro /tmp/imagebuilds/ImageBuildOnly-iso-image.iso /tmp/imagebuilds/esxi_build_cdrom_mount
cp -r /tmp/imagebuilds/esxi_build_cdrom_mount/* /tmp/imagebuilds/esxi_files
chmod 700 /tmp/imagebuilds/esxi_files/boot.cfg
chmod 700 /tmp/imagebuilds/esxi_files/efi/boot/boot.cfg
sed -i -e 's/cdromBoot/ks=cdrom:\/KS.CFG/g'  /tmp/imagebuilds/esxi_files/boot.cfg
sed -i -e 's/cdromBoot/ks=cdrom:\/KS.CFG/g'  /tmp/imagebuilds/esxi_files/efi/boot/boot.cfg

sshpass -f pikvmpass ssh -o StrictHostKeyChecking=no root@pikvm kvmd-helper-otgmsd-remount rw
sshpass -f pikvmpass ssh -o StrictHostKeyChecking=no root@pikvm rm /var/lib/kvmd/msd/.__VMHOST*.complete -f
sshpass -f pikvmpass ssh -o StrictHostKeyChecking=no root@pikvm rm /var/lib/kvmd/msd/VMHOST*.iso -f

FILES="./VMHOST*.CFG"
for f in $FILES
do
       echo "Processing $f ..."
       IFS='-' read -ra NAME <<< "$f"
       hn1=${NAME[0]}
       hn=${hn1/"./"/""}
       \cp "$f" /tmp/imagebuilds/esxi_files/KS.CFG
       fn="/tmp/imagebuilds/$hn-esxi.iso"
       sn="$hn-esxi.iso"
       genisoimage -relaxed-filenames -J -R -o "$fn" -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e efiboot.img -no-emul-boot /tmp/imagebuilds/esxi_files
       echo "Wrote $fn"
       echo "Uploading $fn ..."
       metaname=${sn/"./"/""}
       echo "metaname: $metaname"
       sshpass -f pikvmpass scp -o StrictHostKeyChecking=no "$fn" root@pikvm:/var/lib/kvmd/msd
       sshpass -f pikvmpass ssh -o StrictHostKeyChecking=no root@pikvm touch /var/lib/kvmd/msd/.__"$metaname".complete
       rm "$fn"

done
sleep 10

sshpass -f pikvmpass ssh -o StrictHostKeyChecking=no root@pikvm kvmd-helper-otgmsd-remount ro

umount /tmp/imagebuilds/esxi_build_cdrom_mount
rm -rf /tmp/imagebuilds
rm -f /tmp/download.zip
rm -rf /tmp/certs
