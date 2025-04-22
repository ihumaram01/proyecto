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
echo "BASE      dc=LDAP,dc=local" | sudo tee -a /etc/ldap/ldap.conf
echo "URI       ldap://10.0.2.30:389" | sudo tee -a /etc/ldap/ldap.conf
echo "rootbinddn cn=admin,dc=LDAP,dc=local" | sudo tee -a /etc/ldap/ldap.conf
echo "pam_password md5" | sudo tee -a /etc/ldap/ldap.conf

# Configuración de /etc/nsswitch.conf
echo "Modificando /etc/nsswitch.conf..."
sed -i 's/^passwd:.*/passwd:     files ldap/' /etc/nsswitch.conf
sed -i 's/^group:.*/group:      files ldap/' /etc/nsswitch.conf
sed -i 's/^shadow:.*/shadow:     files ldap/' /etc/nsswitch.conf

# Crear archivo /etc/ldap.secret
echo "Creando archivo /etc/ldap.secret..."
echo 'Admin1' | sudo tee /etc/ldap.secret > /dev/null
sudo chmod 600 /etc/ldap.secret
sudo chown root:root /etc/ldap.secret

# Reiniciar servicios
echo "Reiniciando servicios necesarios..."
sudo systemctl restart nscd
sudo systemctl restart nslcd || echo "nslcd no está instalado, ignorado"

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

#!/bin/bash

# Ruta del archivo de configuración de SSH
SSHD_CONFIG="/etc/ssh/sshd_config"

# Realizamos una copia de seguridad del archivo original
cp $SSHD_CONFIG ${SSHD_CONFIG}.bak

# Eliminar las líneas anteriores
sed -i '/^PasswordAuthentication/d' $SSHD_CONFIG
sed -i '/^KbdInteractiveAuthentication/d' $SSHD_CONFIG
sed -i '/^UsePAM/d' $SSHD_CONFIG
sed -i '/^PubkeyAuthentication/d' $SSHD_CONFIG

# Escribir las nuevas configuraciones
echo "PasswordAuthentication yes" >> $SSHD_CONFIG
echo "KbdInteractiveAuthentication yes" >> $SSHD_CONFIG
echo "UsePAM yes" >> $SSHD_CONFIG
echo "PubkeyAuthentication yes" >> $SSHD_CONFIG

# Reiniciar el servicio SSH
sudo systemctl restart ssh

# Reiniciar el sistema
echo "Reiniciando el sistema..."
sudo reboot
