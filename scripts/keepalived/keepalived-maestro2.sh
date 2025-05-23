#!/bin/bash
# Script para configurar Keepalived en el Maestro 2 (Backup)

# Pedir al usuario la dirección IP virtual
echo "Ingrese la dirección IP virtual que tendra el servicio:"
read virtual_ip

# Verificar que el usuario haya ingresado una IP
if [[ -z "$virtual_ip" ]]; then
    echo "No se ha ingresado una IP. Saliendo..."
    exit 1
fi

echo "Instalando Keepalived..."
sudo apt update && sudo apt install -y keepalived

echo "Creando archivo de configuración para Maestro 2..."
cat <<EOF | sudo tee /etc/keepalived/keepalived.conf
vrrp_instance TLHA {
    state BACKUP
    interface ens5
    virtual_router_id 51
    priority 100
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

echo "Keepalived configurado correctamente en Maestro 2 (Backup)"
