echo "==================== INICIO DEL SCRIPT ===================="

# ARCHIVO DE LOG
LOG_FILE="laboratorio.log"
#exec > "$LOG_FILE" 2>&1

###########################################
#            VARIABLES DE PRUEBA          #
###########################################

# Variables VPC
REGION="us-east-1"

# Variables AMI-ID (Ubuntu server 24.04) y CLAVE SSH
KEY_NAME="ssh-proyecto-ivan"
AMI_ID="ami-04b4f1a9cf54c11d0" # Ubuntu Server 24.04

# Tipo de instancia y tamaño del disco
INSTANCE_TYPE="t3.micro"
VOLUME_SIZE=30

echo "Creando clave SSH..."

# Crear par de claves SSH y almacenar la clave en una variable
PEM_KEY=$(aws ec2 create-key-pair \
    --key-name "${KEY_NAME}" \
    --query "KeyMaterial" \
    --output text)

# Guardar la clave en un archivo
echo "${PEM_KEY}" > "${KEY_NAME}.pem"
chmod 400 "${KEY_NAME}.pem"
echo "Clave SSH creada y almacenada en: ${KEY_NAME}.pem"

###########################################
#                 VPC                     #
###########################################

echo "Creando VPC y subredes..."

# Crear VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block "10.0.0.0/16" --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value="vpc-proyecto-ivan"

# Crear Subnet pública
SUBNET_PUBLIC_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "10.0.1.0/24" --availability-zone "${REGION}a" --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources "$SUBNET_PUBLIC_ID" --tags Key=Name,Value="subnet-publica-proyecto-ivan"

# Crear Subnet privada
SUBNET_PRIVATE_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "10.0.2.0/24" --availability-zone "${REGION}a" --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources "$SUBNET_PRIVATE_ID" --tags Key=Name,Value="subnet-privada-proyecto-ivan"

echo "Creando Internet Gateway y tabla de rutas públicas..."

# Crear Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" > /dev/null

# Crear Tabla de Rutas Públicas
RTB_PUBLIC_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$RTB_PUBLIC_ID" --destination-cidr-block "0.0.0.0/0" --gateway-id "$IGW_ID" > /dev/null
aws ec2 associate-route-table --subnet-id "$SUBNET_PUBLIC_ID" --route-table-id "$RTB_PUBLIC_ID" > /dev/null


echo "Creando NAT Gateway y tabla de rutas privadas..."

# Crear Elastic IP y NAT Gateway
EIP_ID=$(aws ec2 allocate-address --query 'AllocationId' --output text)
NAT_ID=$(aws ec2 create-nat-gateway \
    --subnet-id "$SUBNET_PUBLIC_ID" \
    --allocation-id "$EIP_ID" \
    --query 'NatGateway.NatGatewayId' \
    --output text)

# Esperar hasta que el NAT Gateway esté disponible
while true; do
    STATUS=$(aws ec2 describe-nat-gateways \
        --nat-gateway-ids "$NAT_ID" \
        --query 'NatGateways[0].State' \
        --output text 2>/dev/null)
    echo "Estado del NAT Gateway: $STATUS"
    if [ "$STATUS" == "available" ]; then
        break
    fi
    sleep 10
done

# Crear Tabla de Rutas Privadas
RTB_PRIVATE_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$RTB_PRIVATE_ID" --destination-cidr-block "0.0.0.0/0" --nat-gateway-id "$NAT_ID" > /dev/null
aws ec2 associate-route-table --subnet-id "$SUBNET_PRIVATE_ID" --route-table-id "$RTB_PRIVATE_ID" > /dev/null


###########################################
#         GRUPOS DE SEGURIDAD             #
###########################################

echo "Creando Grupos de Seguridad..."

# Grupo de seguridad para WireGuard VPN
SG_WIREGUARD_ID=$(aws ec2 create-security-group --group-name "sg_wireguard" --description "SG para WireGuard VPN" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_WIREGUARD_ID" --protocol udp --port 51820 --cidr "0.0.0.0/0"
aws ec2 authorize-security-group-ingress --group-id "$SG_WIREGUARD_ID" --protocol tcp --port 22 --cidr "0.0.0.0/0"

# Grupo de seguridad para LDAP
SG_LDAP_ID=$(aws ec2 create-security-group --group-name "sg_ldap" --description "SG para LDAP" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_LDAP_ID" --protocol tcp --port 22 --cidr "0.0.0.0/0" # SSH
aws ec2 authorize-security-group-ingress --group-id "$SG_LDAP_ID" --protocol tcp --port 389 --cidr "10.0.2.0/24" # LDAP
aws ec2 authorize-security-group-ingress --group-id "$SG_LDAP_ID" --protocol icmp --port -1 --cidr "10.0.2.0/24" # PING

# Grupo de seguridad para ThinLinc
SG_THINLINC_ID=$(aws ec2 create-security-group --group-name "sg_thinlinc" --description "SG para ThinLinc" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_THINLINC_ID" --protocol tcp --port 22 --cidr "0.0.0.0/0" # SSH
aws ec2 authorize-security-group-ingress --group-id "$SG_THINLINC_ID" --protocol tcp --port 300 --cidr "10.0.2.0/24" # ThinLinc
aws ec2 authorize-security-group-ingress --group-id "$SG_THINLINC_ID" --protocol tcp --port 443 --cidr "10.0.2.0/24" # ThinLinc
aws ec2 authorize-security-group-ingress --group-id "$SG_THINLINC_ID" --protocol tcp --port 904 --cidr "10.0.2.0/24" # ThinLinc
aws ec2 authorize-security-group-ingress --group-id "$SG_THINLINC_ID" --protocol tcp --port 5901-5999 --cidr "10.0.2.0/24" # ThinLinc
aws ec2 authorize-security-group-ingress --group-id "$SG_THINLINC_ID" --protocol icmp --port -1 --cidr "10.0.2.0/24" # PING


###########################################
#         INSTANCIAS EC2                  #
###########################################

echo "Lanzando instancias EC2..."

echo "  Lanzando VPN WireGuard..."

# Instancia para WireGuard VPN
INSTANCE_NAME="VPNWireguard"
SUBNET_ID="$SUBNET_PUBLIC_ID"
SECURITY_GROUP_ID="$SG_WIREGUARD_ID"
PRIVATE_IP="10.0.1.10"

HOSTNAME="VPNWireguard"
USER_DATA=$(cat <<EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo apt update
sudo apt install -y unzip git
hostnamectl set-hostname $HOSTNAME
cd /home/ubuntu
git clone http://github.com/ihumaram01/proyecto.git || echo "Fallo al clonar" >> /var/log/user-data.log
chown -R ubuntu:ubuntu proyecto
sudo chmod +x /home/ubuntu/proyecto/scripts/wireguard.sh
EOF
)

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_ID,AssociatePublicIpAddress=true,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --user-data "$USER_DATA" \
    --query "Instances[0].InstanceId" \
    --output text)
echo "${INSTANCE_NAME} creada: ${INSTANCE_ID}"

echo "  Lanzando LDAP..."

# Instancia para LDAP
INSTANCE_NAME="LDAP"
SUBNET_ID="$SUBNET_PRIVATE_ID"
SECURITY_GROUP_ID="$SG_LDAP_ID"
PRIVATE_IP="10.0.2.30"

HOSTNAME="LDAP"
USER_DATA=$(cat <<EOF
#!/bin/bash
apt update
apt install -y unzip git
hostnamectl set-hostname $HOSTNAME
cd /home/ubuntu
git clone http://github.com/ihumaram01/proyecto.git || echo "Fallo al clonar" >> /var/log/user-data.log
chown -R ubuntu:ubuntu proyecto
sudo chmod +x /home/ubuntu/proyecto/scripts/ldap/ldap-server.sh
EOF
)


INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_ID,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --user-data "$USER_DATA" \
    --query "Instances[0].InstanceId" \
    --output text)
echo "${INSTANCE_NAME} creada: ${INSTANCE_ID}"

echo "  Lanzando ThinLinc Agente1..."

# Instancia para ThinLinc Agente1
INSTANCE_NAME="ThinLincAgente1"
PRIVATE_IP="10.0.2.21"
SECURITY_GROUP_ID="$SG_THINLINC_ID"

HOSTNAME="ThinLincAgente1"
USER_DATA=$(cat <<EOF
#!/bin/bash
apt update
apt install -y unzip git
hostnamectl set-hostname $HOSTNAME
cd /home/ubuntu
git clone http://github.com/ihumaram01/proyecto.git || echo "Fallo al clonar" >> /var/log/user-data.log
chown -R ubuntu:ubuntu proyecto
sudo chmod +x /home/ubuntu/proyecto/scripts/ldap/ldap-cliente.sh
sudo chmod +x /home/ubuntu/proyecto/scripts/aws/tlagente.sh
sudo ./proyecto/scripts/aws/tlagente.sh
EOF
)

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_PRIVATE_ID,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --user-data "$USER_DATA" \
    --query "Instances[0].InstanceId" \
    --output text)
echo "${INSTANCE_NAME} creada: ${INSTANCE_ID}"

echo "  Lanzando ThinLinc Agente2..."

# Instancia para ThinLinc Agente2
INSTANCE_NAME="ThinLincAgente2"
PRIVATE_IP="10.0.2.22"

HOSTNAME="ThinLincAgente2"
USER_DATA=$(cat <<EOF
#!/bin/bash
apt update
apt install -y unzip git
hostnamectl set-hostname $HOSTNAME
cd /home/ubuntu
git clone http://github.com/ihumaram01/proyecto.git || echo "Fallo al clonar" >> /var/log/user-data.log
chown -R ubuntu:ubuntu proyecto
sudo chmod +x /home/ubuntu/proyecto/scripts/ldap/ldap-cliente.sh
sudo chmod +x /home/ubuntu/proyecto/scripts/aws/tlagente.sh
sudo ./proyecto/scripts/aws/tlagente.sh
EOF
)

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_PRIVATE_ID,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --user-data "$USER_DATA" \
    --query "Instances[0].InstanceId" \
    --output text)
echo "${INSTANCE_NAME} creada: ${INSTANCE_ID}"

echo "  Lanzando ThinLinc Maestro1..."

# Instancia para ThinLinc Maestro1
INSTANCE_NAME="ThinLincMaestro1"
PRIVATE_IP="10.0.2.11"

HOSTNAME="ThinLincMaestro1"
USER_DATA=$(cat <<EOF
#!/bin/bash
apt update
apt install -y unzip git
hostnamectl set-hostname $HOSTNAME
cd /home/ubuntu
git clone http://github.com/ihumaram01/proyecto.git || echo "Fallo al clonar" >> /var/log/user-data.log
chown -R ubuntu:ubuntu proyecto
sudo chmod +x /home/ubuntu/proyecto/scripts/aws/keepalived-maestro1.sh
sudo ./proyecto/scripts/aws/keepalived-maestro1.sh
sudo chmod +x /home/ubuntu/proyecto/scripts/ldap/ldap-cliente.sh
sudo chmod +x /home/ubuntu/proyecto/scripts/aws/tlmaestro.sh
sudo ./proyecto/scripts/aws/tlmaestro.sh
EOF
)

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_PRIVATE_ID,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --user-data "$USER_DATA" \
    --query "Instances[0].InstanceId" \
    --output text)
echo "${INSTANCE_NAME} creada: ${INSTANCE_ID}"

echo "  Lanzando ThinLinc Maestro2..."

# Instancia para ThinLinc Maestro2
INSTANCE_NAME="ThinLincMaestro2"
PRIVATE_IP="10.0.2.12"

HOSTNAME="ThinLincMaestro2"
USER_DATA=$(cat <<EOF
#!/bin/bash
apt update
apt install -y unzip git
hostnamectl set-hostname $HOSTNAME
cd /home/ubuntu
git clone http://github.com/ihumaram01/proyecto.git || echo "Fallo al clonar" >> /var/log/user-data.log
chown -R ubuntu:ubuntu proyecto
sudo chmod +x /home/ubuntu/proyecto/scripts/aws/keepalived-maestro2.sh
sudo ./proyecto/scripts/aws/keepalived-maestro2.sh
sudo chmod +x /home/ubuntu/proyecto/scripts/ldap/ldap-cliente.sh
sudo chmod +x /home/ubuntu/proyecto/scripts/aws/tlmaestro.sh
sudo ./proyecto/scripts/aws/tlmaestro.sh
EOF
)

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,DeleteOnTermination=true}" \
    --network-interfaces "SubnetId=$SUBNET_PRIVATE_ID,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --user-data "$USER_DATA" \
    --query "Instances[0].InstanceId" \
    --output text)
echo "${INSTANCE_NAME} creada: ${INSTANCE_ID}"
echo "✅ Infraestructura desplegada correctamente."
