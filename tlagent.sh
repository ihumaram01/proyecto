#!/bin/bash

# Ruta al archivo de configuración
CONFIG_FILE="/opt/thinlinc/etc/conf.d/vsmagent.hconf"

# Solicitar al usuario la IP del servidor maestro
echo "Ingresa la IP virtual de tu servicio (master_hostname):"
read MASTER_HOSTNAME

# Solicitar al usuario las IPs de los clientes permitidos
echo "Ingresa las IPs de los servidores maestros separadas por espacio (ejemplo: 192.168.1.1 192.168.1.2):"
read ALLOWED_CLIENTS

# Cambiar master_hostname de localhost a la IP proporcionada
sed -i "s/^master_hostname=localhost/master_hostname=$MASTER_HOSTNAME/" $CONFIG_FILE

# Cambiar allowed_clients vacío a las IPs proporcionadas por el usuario
sed -i "s/^allowed_clients=.*/allowed_clients=$ALLOWED_CLIENTS/" $CONFIG_FILE

# Imprimir mensaje de éxito
echo "Los cambios han sido aplicados correctamente"
