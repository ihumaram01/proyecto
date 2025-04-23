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
        send "agent\r"
        exp_continue
    }
    -re "Externally reachable address.*\[ip/hostname/manual\]" {
        send "ip\r"
        exp_continue
    }
    -re "Administrator email.*" {
        send "ihumaram01@educantabria.es\r"
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
CONFIG_FILE="/opt/thinlinc/etc/conf.d/vsmagent.hconf"

# IP virtual del maestro
MASTER_HOSTNAME="10.0.2.100"

# IPs de los clientes permitidos
ALLOWED_CLIENTS="10.0.2.21 10.0.2.22"

# Cambiar master_hostname de localhost a la IP proporcionada
sed -i "s/^master_hostname=localhost/master_hostname=$MASTER_HOSTNAME/" "$CONFIG_FILE"

# Cambiar allowed_clients vacío a las IPs proporcionadas
sed -i "s/^allowed_clients=.*/allowed_clients=$ALLOWED_CLIENTS/" "$CONFIG_FILE"

# Instalar entorno de escritorio
sudo apt install xfce4 xfce4-goodies -y

# Instalar servidor VNC
sudo apt install tigervnc-standalone-server tigervnc-viewer -y

# Mensaje final
echo "Los cambios han sido aplicados correctamente."
