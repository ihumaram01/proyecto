#!/bin/bash

# IP o hostname del servidor Zabbix
ZABBIX_SERVER="10.0.1.20"

# Instalar el repositorio oficial de Zabbix 7.0
sudo apt update
sudo apt install -y wget
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_7.0-2+ubuntu24.04_all.deb
sudo apt update

# Instalar el agente de Zabbix
sudo apt install -y zabbix-agent

# Configurar el agente para conectarse al servidor
sudo sed -i "s/^Server=127.0.0.1/Server=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf
sudo sed -i "s/^ServerActive=127.0.0.1/ServerActive=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf
sudo sed -i "s/^Hostname=Zabbix server/Hostname=$(hostname)/" /etc/zabbix/zabbix_agentd.conf

# Iniciar y habilitar el servicio del agente
sudo systemctl restart zabbix-agent
sudo systemctl enable zabbix-agent

sudo apt install rsyslog -y
sudo chgrp zabbix /var/log/auth.log
sudo chmod 640 /var/log/auth.log

echo "✅ Zabbix Agent instalado y conectado a $ZABBIX_SERVER como '$(hostname)'"
