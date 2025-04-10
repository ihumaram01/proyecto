#!/bin/bash

# ARCHIVO DE LOG
LOG_FILE="laboratorio.log"
exec > "$LOG_FILE" 2>&1

###########################################
#            VARIABLES DE PRUEBA          #
###########################################

# Variables VPC
REGION="us-east-1"
# Variables AMI-ID (Ubuntu server 24.04) y CLAVE SSH
KEY_NAME="ssh-proyecto-ivan"
AMI_ID="ami-04b4f1a9cf54c11d0" # Ubuntu Server 24.04

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

# Crear VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block "10.0.0.0/16" --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value="vpc-proyecto-ivan"

# Crear Subnet pública
SUBNET_PUBLIC_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "10.0.1.0/24" --availability-zone "${REGION}a" --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources "$SUBNET_PUBLIC_ID" --tags Key=Name,Value="subnet-publica-proyecto-ivan"

# Crear Subnet privada
SUBNET_PRIVATE_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "10.0.2.0/24" --availability-zone "${REGION}a" --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources "$SUBNET_PRIVATE_ID" --tags Key=Name,Value="subnet-privada-proyecto-ivan"

# Crear Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"

# Crear Tabla de Rutas Públicas
RTB_PUBLIC_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$RTB_PUBLIC_ID" --destination-cidr-block "0.0.0.0/0" --gateway-id "$IGW_ID"
aws ec2 associate-route-table --subnet-id "$SUBNET_PUBLIC_ID" --route-table-id "$RTB_PUBLIC_ID"

# Crear Elastic IP y NAT Gateway
EIP_ID=$(aws ec2 allocate-address --query 'AllocationId' --output text)
NAT_ID=$(aws ec2 create-nat-gateway --subnet-id "$SUBNET_PUBLIC_ID" --allocation-id "$EIP_ID" --query 'NatGateway.NatGatewayId' --output text)

echo "Creando GATEWAY NAT..."
while true; do
    STATUS=$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT_ID" --query 'NatGateways[0].State' --output text)
    echo "Estado del NAT Gateway: $STATUS"
    if [ "$STATUS" == "available" ]; then
        break
    fi
    sleep 10
done

# Crear Tabla de Rutas Privadas
RTB_PRIVATE_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$RTB_PRIVATE_ID" --destination-cidr-block "0.0.0.0/0" --nat-gateway-id "$NAT_ID"
aws ec2 associate-route-table --subnet-id "$SUBNET_PRIVATE_ID" --route-table-id "$RTB_PRIVATE_ID"

###########################################
#         GRUPOS DE SEGURIDAD             #
###########################################

# WireGuard
SG_WIREGUARD_ID=$(aws ec2 create-security-group --group-name "sg_wireguard" --description "SG para WireGuard VPN" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_WIREGUARD_ID" --protocol udp --port 51820 --cidr "0.0.0.0/0"
aws ec2 authorize-security-group-ingress --group-id "$SG_WIREGUARD_ID" --protocol tcp --port 22 --cidr "0.0.0.0/0"
aws ec2 authorize-security-group-egress --group-id "$SG_WIREGUARD_ID" --protocol -1 --port all --cidr "0.0.0.0/0"

# LDAP
SG_LDAP_ID=$(aws ec2 create-security-group --group-name "sg_ldap" --description "SG para LDAP" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_LDAP_ID" --protocol tcp --port 22 --cidr "0.0.0.0/0"
aws ec2 authorize-security-group-ingress --group-id "$SG_LDAP_ID" --protocol tcp --port 389 --cidr "10.0.2.0/24"
aws ec2 authorize-security-group-egress --group-id "$SG_LDAP_ID" --protocol -1 --port all --cidr "0.0.0.0/0"

# ThinLinc
SG_THINLINC_ID=$(aws ec2 create-security-group --group-name "sg_thinlinc" --description "SG para ThinLinc" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_THINLINC_ID" --protocol tcp --port 22 --cidr "0.0.0.0/0"
aws ec2 authorize-security-group-ingress --group-id "$SG_THINLINC_ID" --protocol tcp --port 5901-5999 --cidr "10.0.2.0/24"
aws ec2 authorize-security-group-egress --group-id "$SG_THINLINC_ID" --protocol -1 --port all --cidr "0.0.0.0/0"

###########################################
#         INSTANCIAS EC2 CON APPDATA      #
###########################################

crear_instancia() {
    INSTANCE_NAME=$1
    SUBNET_ID=$2
    SECURITY_GROUP_ID=$3
    PRIVATE_IP=$4

    export HOSTNAME=$INSTANCE_NAME
    USER_DATA=$(cat <<EOF | envsubst | base64
#!/bin/bash
apt update
apt install -y unzip git
hostnamectl set-hostname \$HOSTNAME
EOF
)

    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type "t2.micro" \
        --key-name "$KEY_NAME" \
        --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=8,VolumeType=gp3,DeleteOnTermination=true}" \
        --network-interfaces "SubnetId=$SUBNET_ID,AssociatePublicIpAddress=true,DeviceIndex=0,PrivateIpAddresses=[{Primary=true,PrivateIpAddress=$PRIVATE_IP}],Groups=[$SECURITY_GROUP_ID]" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
        --user-data "$USER_DATA" \
        --query "Instances[0].InstanceId" \
        --output text)
    
    echo "$INSTANCE_NAME creada: $INSTANCE_ID"
}

# Llamadas a la función para cada instancia
crear_instancia "VPNWireguard" "$SUBNET_PUBLIC_ID" "$SG_WIREGUARD_ID" "10.0.1.10"
crear_instancia "LDAP" "$SUBNET_PRIVATE_ID" "$SG_LDAP_ID" "10.0.2.30"
crear_instancia "ThinLincAgente1" "$SUBNET_PRIVATE_ID" "$SG_THINLINC_ID" "10.0.2.21"
crear_instancia "ThinLincAgente2" "$SUBNET_PRIVATE_ID" "$SG_THINLINC_ID" "10.0.2.22"
crear_instancia "ThinLincMaestro1" "$SUBNET_PRIVATE_ID" "$SG_THINLINC_ID" "10.0.2.11"
crear_instancia "ThinLincMaestro2" "$SUBNET_PRIVATE_ID" "$SG_THINLINC_ID" "10.0.2.12"
