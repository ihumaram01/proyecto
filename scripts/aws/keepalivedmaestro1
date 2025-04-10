#!/bin/bash
# Script para configurar Keepalived en el Maestro 1 (Primario)

# Dirección IP virtual fija
virtual_ip="10.0.2.100"

echo "Instalando Keepalived..."
sudo apt update && sudo apt install -y keepalived

echo "Creando archivo de configuración para Maestro 1..."
cat <<EOF | sudo tee /etc/keepalived/keepalived.conf
vrrp_instance TLHA {
    state MASTER
    interface ens5
    virtual_router_id 51
    priority 150
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass thinlinc123
    }
    virtual_ipaddress {
        $virtual_ip
    }
}
EOF

echo "Habilitando y reiniciando Keepalived..."
sudo systemctl enable keepalived
sudo systemctl restart keepalived

echo "Keepalived configurado correctamente en Maestro 1 (Primario) con IP virtual: $virtual_ip"
