#!/bin/bash
set -euo pipefail

SIZE_SQL=30
SIZE_VEEAM=40

VG_NAME="repoimm"
LV_VEEAM="repoveeam"
LV_SQL="repoveeamsql"

MP_VEEAM="/repoveeam"
MP_SQL="/repoveeamsql"

echo "=== Discos detectados (lsblk) ==="
lsblk

echo "****** Enter disk as example /dev/sdb ******: "
read -r DISK

if [[ -z "${DISK}" ]]; then
  echo "ERROR: No se proporciono disco."
  exit 1
fi

if [[ ! -b "${DISK}" ]]; then
  echo "ERROR: ${DISK} no es un dispositivo de bloque valido."
  exit 1
fi

echo "=== ATENCION: Se inicializara como PV el disco: ${DISK} ==="
echo "Escribe YES para continuar: "
read -r CONFIRM
if [[ "${CONFIRM}" != "YES" ]]; then
  echo "Cancelado."
  exit 0
fi

echo "=== Creando PV/VG ==="
pvcreate -ff -y "${DISK}"
vgcreate "${VG_NAME}" "${DISK}"

echo "=== Creando LVs con porcentaje del VG ==="
lvcreate -l ${SIZE_VEEAM}%VG --name "${LV_VEEAM}" "${VG_NAME}"
lvcreate -l ${SIZE_SQL}%VG --name "${LV_SQL}" "${VG_NAME}"

echo "=== Formateando XFS ==="
mkfs.xfs -f -K -b size=4096 -m reflink=1,crc=1 "/dev/${VG_NAME}/${LV_VEEAM}"
mkfs.xfs -f -K -b size=4096 -m reflink=1,crc=1 "/dev/${VG_NAME}/${LV_SQL}"

echo "=== Creando puntos de montaje y montando ==="
mkdir -p "${MP_VEEAM}" "${MP_SQL}"
mount "/dev/${VG_NAME}/${LV_VEEAM}" "${MP_VEEAM}"
mount "/dev/${VG_NAME}/${LV_SQL}" "${MP_SQL}"

echo "=== Creando usuario veeamrepo si no existe ==="
if ! id veeamrepo >/dev/null 2>&1; then
  adduser veeamrepo
fi

echo "=== Creando carpetas y permisos ==="
mkdir -p "${MP_VEEAM}/backups" "${MP_SQL}/backups"
chown veeamrepo:veeamrepo "${MP_VEEAM}/backups" "${MP_SQL}/backups"
chmod 700 "${MP_VEEAM}/backups" "${MP_SQL}/backups"

echo "=== Agregando a /etc/fstab por UUID ==="
UUID_VEEAM="$(blkid -s UUID -o value "/dev/${VG_NAME}/${LV_VEEAM}")"
UUID_SQL="$(blkid -s UUID -o value "/dev/${VG_NAME}/${LV_SQL}")"

echo "******Saving /etc/fstab as /etc/fstab.$$******"
cp -p /etc/fstab "/etc/fstab.$$"

echo "******Adding mount entries to /etc/fstab******"
echo "UUID=${UUID_VEEAM} ${MP_VEEAM} xfs defaults 1 1" >> /etc/fstab
echo "UUID=${UUID_SQL} ${MP_SQL} xfs defaults 1 1" >> /etc/fstab

echo "=== Listo ==="
echo "Normal repo : ${MP_VEEAM} ${SIZE_VEEAM}%"
echo "SQL repo    : ${MP_SQL} ${SIZE_SQL}%"
echo "*****Recuerda asignarle una contraseña al usuario veeamrepo******"
