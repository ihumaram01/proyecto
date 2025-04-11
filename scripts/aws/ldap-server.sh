#!/bin/bash
set -e

# Configuración previa: definir dominio y contraseña LDAP
LDAP_DOMAIN="LDAP.local"
LDAP_ORGANIZATION="tdc"
LDAP_PASSWORD="Admin1"  # Debe ser fuerte si es producción
LDAP_BASE_DN="dc=LDAP,dc=local"
LDAP_ADMIN_DN="cn=admin,${LDAP_BASE_DN}"

# Preconfigurar slapd para evitar modo interactivo
echo "slapd slapd/no_configuration boolean false" | sudo debconf-set-selections
echo "slapd slapd/domain string ${LDAP_DOMAIN}" | sudo debconf-set-selections
echo "slapd shared/organization string ${LDAP_ORGANIZATION}" | sudo debconf-set-selections
echo "slapd slapd/password1 password ${LDAP_PASSWORD}" | sudo debconf-set-selections
echo "slapd slapd/password2 password ${LDAP_PASSWORD}" | sudo debconf-set-selections
echo "slapd slapd/backend select MDB" | sudo debconf-set-selections
echo "slapd slapd/purge_database boolean true" | sudo debconf-set-selections
echo "slapd slapd/move_old_database boolean true" | sudo debconf-set-selections
echo "slapd slapd/allow_ldap_v2 boolean false" | sudo debconf-set-selections

# Instalar paquetes necesarios
sudo DEBIAN_FRONTEND=noninteractive apt update
sudo DEBIAN_FRONTEND=noninteractive apt install slapd ldap-utils libnss-ldap libpam-ldap nscd -y

# Configurar /etc/ldap/ldap.conf
cat <<EOF | sudo tee /etc/ldap/ldap.conf
BASE    ${LDAP_BASE_DN}
URI     ldap://10.0.2.30
EOF

# Configurar NSS
sudo sed -i 's/^passwd:.*/passwd:         files ldap/' /etc/nsswitch.conf
sudo sed -i 's/^group:.*/group:          files ldap/' /etc/nsswitch.conf
sudo sed -i 's/^shadow:.*/shadow:         files ldap/' /etc/nsswitch.conf

# Crear unidad organizativa
cat <<EOF | sudo tee base.ldif
dn: ou=usuarios,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: usuarios
EOF

# Agregar la unidad al LDAP
ldapadd -x -D "${LDAP_ADMIN_DN}" -w "${LDAP_PASSWORD}" -f base.ldif

# Crear usuario
cat <<EOF | sudo tee usuario.ldif
dn: uid=ihumara,ou=usuarios,${LDAP_BASE_DN}
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
userPassword: $(slappasswd -s Admin1)
EOF

# Agregar usuario al LDAP
ldapadd -x -D "${LDAP_ADMIN_DN}" -w "${LDAP_PASSWORD}" -f usuario.ldif

# Habilitar creación automática de home
sudo bash -c 'cat <<EOF > /usr/share/pam-configs/mkhomedir
Name: Create home directory on login
Default: yes
Priority: 900
Session-Type: Additional
Session:
        required        pam_mkhomedir.so umask=0077 skel=/etc/skel
EOF'

sudo pam-auth-update --package

# Ajustar PAM adicionalmente
echo "account required pam_unix.so" | sudo tee -a /etc/pam.d/common-account
echo "session required pam_limits.so" | sudo tee -a /etc/pam.d/common-session

# Reiniciar nscd (opcional, mejora el cacheo de usuarios/grupos)
sudo systemctl restart nscd

echo "✅ Configuración LDAP completada de forma automática."
