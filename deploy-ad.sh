#!/bin/bash

# Cambiar temporalmente el DNS
sed -i 's/127.0.0.1/8.8.8.8/' /etc/resolv.conf

# Actualizar el sistema
apt-get update -y && apt-get upgrade -y

# Instalar paquetes necesarios
apt-get install acl attr samba samba-client winbind libpam-winbind libnss-winbind dnsutils python3-setproctitle -y

# Borrar archivos antiguos de Samba
for VARIABLE in $(smbd -b | egrep "LOCKDIR|STATEDIR|CACHEDIR|PRIVATE_DIR" | cut -d ":" -f2)

do
   echo "Borrando *.tdb y *.ldb en $VARIABLE"
   rm -Rf $VARIABLE/*.tdb
   rm -Rf $VARIABLE/*.ldb

done

# Instalar paquetes adicionales
apt install sssd-tools sssd libnss-sss libpam-sss adcli packagekit sssd-ad sssd-tools realmd -y

# Detener y deshabilitar servicios innecesarios
systemctl stop smbd nmbd winbind
systemctl disable smbd nmbd winbind

# Provisionar Samba AD
samba-tool domain provision --server-role=dc --use-rfc2307 --dns-backend=SAMBA_INTERNAL --realm=MRAI-TIPY-UY.DUCKDNS.ORG --domain=MRAI-TIPY --adminpass=Passw0rd

# Validar si la provisión fue exitosa
if [ $? -ne 0 ]; then
    echo "Error al provisionar el dominio de Samba."
    exit 1
fi

# Restaurar el archivo resolv.conf
sed -i 's/8.8.8.8/127.0.0.1/' /etc/resolv.conf

# Comprobar la configuración del DNS
host -t SRV _ldap._tcp.MRAI-TIPY-UY.DUCKDNS.ORG
host -t SRV _kerberos._udp.MRAI-TIPY-UY.DUCKDNS.ORG
host -t A 1-MR-addc01.mrai-tipy-uy.duckdns.org

# Reiniciar y habilitar Samba
systemctl restart samba-ad-dc
systemctl enable samba-ad-dc

