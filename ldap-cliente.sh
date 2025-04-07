#!/bin/bash

# Instalación de paquetes necesarios
echo "Instalando paquetes necesarios..."
apt update
apt install -y libpam-ldap libnss-ldap nss-updatedb nscd ldap-utils slapd

# Configuración interactiva de slapd
echo "Reconfigurar slapd (esto requiere intervención del usuario)..."
dpkg-reconfigure slapd

# Configuración de /etc/ldap/ldap.conf
echo "Editando /etc/ldap/ldap.conf..."
echo "BASE      tdc=LDAP,dc=local" | sudo tee -a /etc/ldap/ldap.conf
echo "URI       ldap://192.168.115.138:389" | sudo tee -a /etc/ldap/ldap.conf

# Modificación de /etc/nsswitch.conf
echo "Modificando /etc/nsswitch.conf..."
sed -i 's/^passwd:.*/passwd:     files ldap/' /etc/nsswitch.conf
sed -i 's/^group:.*/group:      files ldap/' /etc/nsswitch.conf
sed -i 's/^shadow:.*/shadow:     files ldap/' /etc/nsswitch.conf

# Actualizar la base de datos NSS
echo "Actualizando base de datos NSS..."
nss_updatedb ldap

# Configuración de PAM mkhomedir
sudo sed -i '/Session-Interactive-Only: yes/d' /usr/share/pam-configs/mkhomedir
sudo sed -i '/optional/d' /usr/share/pam-configs/mkhomedir
sudo sed -i 's/Default: no/Default: yes/' /usr/share/pam-configs/mkhomedir
sudo sed -i 's/Priority: 0/Priority: 900/' /usr/share/pam-configs/mkhomedir
echo "        required                pam_mkhomedir.so umask=0077 skel=/etc/skel" | sudo tee -a /usr/share/pam-configs/mkhomedir

# Añadir línea a common-session
echo "Modificando /etc/pam.d/common-session..."
COMMON_SESSION="/etc/pam.d/common-session"
grep -q "pam_mkhomedir.so" "$COMMON_SESSION" || sed -i '1isession required pam_mkhomedir.so umask=0077 skel=/etc/skel' "$COMMON_SESSION"

# Actualizar configuración PAM
echo "Actualizando configuración PAM..."
pam-auth-update --force

# Reiniciar el sistema
echo "Reiniciando el sistema..."
sudo reboot
