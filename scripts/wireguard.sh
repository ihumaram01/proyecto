#!/bin/bash

# Variables
WG_DIR="/etc/wireguard"
CLIENTS=("ivanlinux" "ivanmovil" "cosmikal")
SERVER_PRIV_KEY="$WG_DIR/server_private.key"
SERVER_PUB_KEY="$WG_DIR/server_public.key"
SERVER_IP="10.0.3.1/24"
PORT="51820"
NET_IFACE="eth0"  # Cambia esto si tu interfaz no es eth0
DNS_SERVER="1.1.1.1"

# Instalar paquetes necesarios
apt update && apt install -y wireguard qrencode

# Crear directorio base
mkdir -p "$WG_DIR"
cd "$WG_DIR" || exit
umask 077

# Generar claves del servidor
wg genkey | tee "$SERVER_PRIV_KEY" | wg pubkey > "$SERVER_PUB_KEY"

# Leer claves
SERVER_PRIV=$(cat "$SERVER_PRIV_KEY")
SERVER_PUB=$(cat "$SERVER_PUB_KEY")

# Crear directorios de clientes y generar claves
for CLIENT in "${CLIENTS[@]}"; do
    mkdir -p "$WG_DIR/$CLIENT"
    wg genkey | tee "$WG_DIR/$CLIENT/client_private.key" | wg pubkey > "$WG_DIR/$CLIENT/client_public.key"
done

# Crear archivo wg0.conf del servidor
cat > "$WG_DIR/wg0.conf" <<EOF
[Interface]
Address = $SERVER_IP
ListenPort = $PORT
PrivateKey = $SERVER_PRIV
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $NET_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $NET_IFACE -j MASQUERADE

EOF

# IP inicial para clientes
IP_BASE=2

# Crear archivos de configuración de clientes y añadir peers al servidor
for CLIENT in "${CLIENTS[@]}"; do
    CLIENT_PRIV=$(cat "$WG_DIR/$CLIENT/client_private.key")
    CLIENT_PUB=$(cat "$WG_DIR/$CLIENT/client_public.key")
    CLIENT_IP="10.0.3.$IP_BASE"

    # Crear config del cliente
    cat > "$WG_DIR/$CLIENT/$CLIENT.conf" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $CLIENT_IP/32
DNS = $DNS_SERVER

[Peer]
PublicKey = $SERVER_PUB
Endpoint = your-domain.duckdns.org:$PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    # Añadir peer al servidor
    cat >> "$WG_DIR/wg0.conf" <<EOF
[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = $CLIENT_IP/32

EOF

    IP_BASE=$((IP_BASE + 1))
done

# Activar reenvío de IP
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

# Permisos correctos
chmod 600 "$WG_DIR"/*.key "$WG_DIR"/*/*.key "$WG_DIR"/*.conf "$WG_DIR"/*/*.conf

# Habilitar wg-quick al inicio
systemctl enable wg-quick@wg0

echo "✅ WireGuard configurado con éxito para los clientes: ${CLIENTS[*]}"
