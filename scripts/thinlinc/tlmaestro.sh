#!/bin/bash

# Ruta al archivo de configuración
CONFIG_FILE="/opt/thinlinc/etc/conf.d/vsmserver.hconf"

# Solicitar al usuario las IPs de los servidores maestros
echo "Ingresa las IPs de los agentes separadas por espacio (ejemplo: 192.168.1.1 192.168.1.2):"
read AGENT_IPS

# Cambiar max_sessions_per_user de 1 a 0
sed -i 's/^max_sessions_per_user=1/max_sessions_per_user=0/' $CONFIG_FILE

# Cambiar enabled=0 a enabled=1 en /vsmserver/HA
sed -i 's/^enabled=0$/enabled=1/' $CONFIG_FILE

# Cambiar agentes de localhost a las IPs proporcionadas por el usuario
sed -i "s/^agents=127.0.0.1/agents=$AGENT_IPS/" $CONFIG_FILE

# Imprimir mensaje de éxito
echo "Los cambios han sido aplicados correctamente"
