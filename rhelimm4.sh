UUID=$(blkid | grep repoimmsql-repoveeamsql |cut -f2 -d'='|cut -f2 -d'"') 
echo "******Saving /etc/fstab as /etc/fstab.$$******" 
/bin/cp -p /etc/fstab /etc/fstab.$$ 
echo "******Adding /repoveeamsql to /etc/fstab entry******" 
echo "UUID=${UUID} /repoveeamsql xfs defaults 1 1" >> /etc/fstab 
echo "******Please Add The New Repository with veeamrepo single-use credentiales in Veeam Backup & Replication******"
