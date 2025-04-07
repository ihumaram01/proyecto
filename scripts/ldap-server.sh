#!/bin/bash

set -e

# Instalar paquetes necesarios
sudo apt update
sudo apt install slapd ldap-utils -y

# Reconfigurar slapd (se puede hacer no interactivo si se usan debconf-set-selections)
sudo dpkg-reconfigure slapd

# Configurar /etc/ldap/ldap.conf
echo "BASE      tdc=LDAP,dc=local" | sudo tee -a /etc/ldap/ldap.conf
echo "URI       ldap://192.168.115.134:389" | sudo tee -a /etc/ldap/ldap.conf

# Modificar /etc/nsswitch.conf
sudo sed -i 's/^passwd:.*/passwd:\t\tfiles ldap/' /etc/nsswitch.conf
sudo sed -i 's/^group:.*/group:\t\tfiles ldap/' /etc/nsswitch.conf
sudo sed -i 's/^shadow:.*/shadow:\t\tfiles ldap/' /etc/nsswitch.conf

# Crear base.ldif
cat <<EOF | sudo tee base.ldif
dn: ou=usuarios,dc=LDAP,dc=local
objectClass: organizationalUnit
ou: usuarios
EOF

# Agregar base al LDAP
ldapadd -x -D "cn=admin,dc=LDAP,dc=local" -W -f base.ldif

# Crear usuario.ldif
cat <<EOF | sudo tee usuario.ldif
dn: uid=ihumara,ou=usuarios,dc=LDAP,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Ivan Humara
sn: Humara
uid: ihumara
uidNumber: 1001
gidNumber: 1001
homeDirectory: /home/ihumara
loginShell: /bin/bash
userPassword: Admin1
EOF

# Agregar usuario al LDAP
ldapadd -x -D "cn=admin,dc=LDAP,dc=local" -W -f usuario.ldif

# Verificar LDAP
ldapsearch -x -LLL -b "dc=LDAP,dc=local"

# Instalar módulos PAM y NSS
sudo apt install libnss-ldap libpam-ldap -y

# Modificar /usr/share/pam-configs/mkhomedir
sudo sed -i '/Session-Interactive-Only: yes/d' /usr/share/pam-configs/mkhomedir
sudo sed -i '/optional/d' /usr/share/pam-configs/mkhomedir
sudo sed -i 's/Default: no/Default: yes/' /usr/share/pam-configs/mkhomedir
sudo sed -i 's/Priority: 0/Priority: 900/' /usr/share/pam-configs/mkhomedir
echo "        required                pam_mkhomedir.so umask=0077 skel=/etc/skel" | sudo tee -a /usr/share/pam-configs/mkhomedir

# Aplicar cambios de PAM
echo "Aplicando cambios de PAM..."
sudo pam-auth-update

# Modificar common-account
echo "Continuando con la configuracion..."
sudo bash -c 'echo "account required pam_unix.so" >> /etc/pam.d/common-account'

# Modificar common-session
sudo bash -c 'echo "session required pam_limits.so" >> /etc/pam.d/common-session'

echo "Configuración de LDAP completada."
