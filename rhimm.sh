#!/bin/bash
listadiscos=$(lsblk)
echo "List Disks : $listadiscos"
echo "****** Enter disk as example /dev/sdb ******: "
read
pvcreate $REPLY
vgcreate repoimm $REPLY
lvcreate -l 100%FREE --name repoveeam repoimm
mkfs.xfs -b size=4096 -m reflink=1,crc=1 /dev/repoimm/repoveeam
mkdir /repoveeam
mount /dev/repoimm/repoveeam /repoveeam
adduser veeamrepo
echo "****** Please Enter veeamrepo Password ******"
passwd veeamrepo
mkdir /repoveeam/backups
chown veeamrepo:veeamrepo /repoveeam/backups
chmod 700 /repoveeam/backups
UUID=$(blkid | grep repoimm-repoveeam |cut -f2 -d'='|cut -f2 -d'"')
echo "******Saving /etc/fstab as /etc/fstab.$$******"
/bin/cp -p /etc/fstab /etc/fstab.$$
echo "******Adding /repoveeam to /etc/fstab entry******"
echo "UUID=${UUID} /repoveeam xfs defaults 1 1" >> /etc/fstab
