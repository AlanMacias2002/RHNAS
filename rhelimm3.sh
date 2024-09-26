#!/bin/bash 
listadiscos=$(lsblk) 
scandisks=$(rescan-scsi-bus.sh) 

echo "Scanning Disks....: $scandisks" 

echo "List Disks : $listadiscos" 

echo "****** Enter disk as example /dev/sdb ******: " 
read 
pvcreate $REPLY 
vgcreate repoimmsql $REPLY 
lvcreate -l 100%FREE --name repoveeamsql repoimmsql 
mkfs.xfs -b size=4096 -m reflink=1,crc=1 /dev/repoimmsql/repoveeamsql
mkdir /repoveeamsql 
mount /dev/repoimmsql/repoveeamsql /repoveeamsql 
mkdir /repoveeamsql/backups 
chown veeamrepo:veeamrepo /repoveeamsql/backups 
chmod 700 /repoveeamsql/backups 
UUID=$(blkid | grep repoimmsql-repoveeamsql |cut -f2 -d'='|cut -f2 -d'"') 
echo "******Saving /etc/fstab as /etc/fstab.$$******" 
/bin/cp -p /etc/fstab /etc/fstab.$$ 
echo "******Adding /repoveeamsql to /etc/fstab entry******" 
echo "UUID=${UUID} /repoveeamsql xfs defaults 1 1" >> /etc/fstab 
echo "******Please Add The New Repository with veeamrepo single-use credentiales in Veeam Backup & Replication******"
