#!/bin/bash

# Instalar apache2 y postgresql
sudo apt update
sudo apt install -y apache2
sudo apt install -y postgresql

#Instalar el repositorio de zabbix
sudo wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_7.0-2+ubuntu24.04_all.deb
sudo apt update

# Instalar servidor zabbix, interfaz web y agente
sudo apt install -y zabbix-server-pgsql zabbix-frontend-php php8.3-pgsql zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# Crear la base de datos inicial
sudo -u postgres createuser --pwprompt zabbix
sudo -u postgres createdb -O zabbix zabbix
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix

# Configuración de Zabbix Server
echo "Configurando Zabbix Server..."
sudo sed -i 's/# DBPassword=/DBPassword=Admin1/' /etc/zabbix/zabbix_server.conf

# Reiniciar los servicios
sudo systemctl restart zabbix-server zabbix-agent apache2
sudo systemctl enable zabbix-server zabbix-agent apache2
