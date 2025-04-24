#!/bin/bash

# Variables
ZABBIX_DB="zabbix"
ZABBIX_USER="zabbix"
ZABBIX_PASS="Admin1"

echo "[+] Instalando repositorio de Zabbix..."
wget -q https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu22.04_all.deb
dpkg -i zabbix-release_6.4-1+ubuntu22.04_all.deb
apt update

echo "[+] Instalando paquetes de Zabbix y MariaDB..."
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent mariadb-server

echo "[+] Configurando base de datos de Zabbix..."
mysql -uroot <<EOF
CREATE DATABASE ${ZABBIX_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER ${ZABBIX_USER}@localhost IDENTIFIED BY '${ZABBIX_PASS}';
GRANT ALL PRIVILEGES ON ${ZABBIX_DB}.* TO ${ZABBIX_USER}@localhost;
FLUSH PRIVILEGES;
EOF

echo "[+] Importando esquema de la base de datos..."
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -u${ZABBIX_USER} -p${ZABBIX_PASS} ${ZABBIX_DB}

echo "[+] Configurando Zabbix Server..."
sed -i "s|^# DBPassword=.*|DBPassword=${ZABBIX_PASS}|" /etc/zabbix/zabbix_server.conf

echo "[+] Habilitando e iniciando servicios..."
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

echo "[✓] Instalación completa. Accedé desde http://<IP_DE_TU_MAQUINA>/zabbix"
echo "    Usuario: Admin"
echo "    Contraseña: zabbix"
