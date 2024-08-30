#!/bin/bash

rm -f ImageBuildOnly-*
pwsh ./BuildESXiImage.ps1
mkdir ./esxi_build_cdrom_mount
mkdir ./esxi_files
mount -t iso9660 -o loop,ro ImageBuildOnly-iso-image.iso ./esxi_build_cdrom_mount
cp -r ./esxi_build_cdrom_mount/* ./esxi_files
sed -i -e 's/cdromBoot/ks=cdrom:\/KS.CFG/g'  ./esxi_files/boot.cfg
sed -i -e 's/cdromBoot/ks=cdrom:\/KS.CFG/g'  ./esxi_files/efi/boot/boot.cfg

FILES="./VMHOST*.CFG"
for f in $FILES
do
       echo "Processing $f ..."
       IFS='-' read -ra NAME <<< "$f"
       hn1=${NAME[0]}
       hn=${hn1/"./"/""}
       \cp $f ./esxi_files/KS.CFG
       fn="$hn-esxi.iso"
       genisoimage -relaxed-filenames -J -R -o $fn -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e efiboot.img -no-emul-boot ./esxi_files
       echo "Wrote $fn"
done

rm -rf ./esxi_files
umount ./esxi_build_cdrom_mount
rm -r ./esxi_build_cdrom_mount

sshpass -f pikvmpass ssh -o StrictHostKeyChecking=no root@pikvm kvmd-helper-otgmsd-remount rw
sshpass -f pikvmpass ssh -o StrictHostKeyChecking=no root@pikvm rm /var/lib/kvmd/msd/.__VMHOST*.complete -f
sshpass -f pikvmpass ssh -o StrictHostKeyChecking=no root@pikvm rm /var/lib/kvmd/msd/VMHOST*.iso -f

ISOS="./VMHOST*.iso"
for i in $ISOS
do
        echo "Uploading $i ..."
        metaname=${i/"./"/""}
        sshpass -f pikvmpass scp -o StrictHostKeyChecking=no $i root@pikvm:/var/lib/kvmd/msd
        sshpass -f pikvmpass ssh -o StrictHostKeyChecking=no root@pikvm touch /var/lib/kvmd/msd/.__$metaname.complete
done

sshpass -f pikvmpass ssh -o StrictHostKeyChecking=no root@pikvm kvmd-helper-otgmsd-remount ro
