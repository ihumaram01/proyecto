#!/bin/bash

set -e

# Variables
URL="https://www.cendio.com/downloads/server/tl-4.18.0-server.zip"
ARCHIVO="tl-4.18.0-server.zip"
DIR_TEMP="/tmp/thinlinc"

# Instalar expect si no está
apt-get update
apt-get install -y expect unzip wget

# Crear carpeta temporal
mkdir -p "$DIR_TEMP"
cd "$DIR_TEMP"

echo "Descargando ThinLinc..."
wget -q --show-progress "$URL" -O "$ARCHIVO"

echo "Descomprimiendo..."
unzip -o "$ARCHIVO"

# Buscar el script de instalación
INSTALLER=$(find . -name "install-server" | head -n 1)

if [[ -z "$INSTALLER" ]]; then
    echo "No se encontró el instalador en el ZIP."
    exit 1
fi

# Prevenir entorno gráfico
unset DISPLAY
export NO_AT_BRIDGE=1
export DEBIAN_FRONTEND=noninteractive

echo "Ejecutando instalador en modo texto (no GUI)..."
chmod +x "$INSTALLER"

# Script Expect
expect <<EOF
set timeout -1
spawn $INSTALLER --no-gui

expect {
    -re {.*\[(yes|Yes)/[Nn]o\]\?.*} {
        send "yes\r"
        exp_continue
    }
    -re "Run ThinLinc setup now.*\[Yes/no\]\?" {
        send "yes\r"
        exp_continue
    }
    -re "Enter.*continue.*" {
        send "\r"
        exp_continue
    }
    -re "Server type.*\[Master/agent\]" {
        send "Master\r"
        exp_continue
    }
    -re "Externally reachable address.*\[ip/hostname/manual\]" {
        send "ip\r"
        exp_continue
    }
    -re "Administrator email.*" {
        send "prueba@prueba.local\r"
        exp_continue
    }
    -re "Web Administration password.*" {
        send -- "Admin1\r"
        exp_continue
    }
    eof
}
EOF


# Ruta al archivo de configuración
CONFIG_FILE="/opt/thinlinc/etc/conf.d/vsmserver.hconf"

# IPs de los agentes (EDITA ESTA LÍNEA MANUALMENTE)
AGENT_IPS="192.168.115.32 192.168.115.33"

# Cambiar max_sessions_per_user de 1 a 0
sed -i 's/^max_sessions_per_user=1/max_sessions_per_user=0/' "$CONFIG_FILE"

# Cambiar enabled=0 a enabled=1 en /vsmserver/HA
sed -i 's/^enabled=0$/enabled=1/' "$CONFIG_FILE"

# Cambiar agentes de localhost a las IPs proporcionadas
sed -i "s/^agents=127.0.0.1/agents=$AGENT_IPS/" "$CONFIG_FILE"

# Mensaje final
echo "Los cambios han sido aplicados correctamente."
