###########################################
#         INSTANCIAS EC2                  #
###########################################

# Instancia para WireGuard VPN
INSTANCE_NAME="VPNWireguard"
SUBNET_ID="$SUBNET_PUBLIC_ID"
SECURITY_GROUP_ID="$SG_WIREGUARD_ID"
PRIVATE_IP="10.0.1.10"

HOSTNAME="$INSTANCE_NAME"
USER_DATA=$(base64 <<EOF
#!/bin/bash
apt update
apt install -y unzip git
hostnamectl set-hostname $HOSTNAME
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


# Instancia para LDAP
INSTANCE_NAME="LDAP"
SUBNET_ID="$SUBNET_PRIVATE_ID"
SECURITY_GROUP_ID="$SG_LDAP_ID"
PRIVATE_IP="10.0.2.30"

HOSTNAME="$INSTANCE_NAME"
USER_DATA=$(base64 <<EOF
#!/bin/bash
apt update
apt install -y unzip git
hostnamectl set-hostname $HOSTNAME
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


# Instancia para ThinLinc Agente1
INSTANCE_NAME="ThinLincAgente1"
PRIVATE_IP="10.0.2.21"
SECURITY_GROUP_ID="$SG_THINLINC_ID"

HOSTNAME="$INSTANCE_NAME"
USER_DATA=$(base64 <<EOF
#!/bin/bash
apt update
apt install -y unzip git
hostnamectl set-hostname $HOSTNAME
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


# Instancia para ThinLinc Agente2
INSTANCE_NAME="ThinLincAgente2"
PRIVATE_IP="10.0.2.22"

HOSTNAME="$INSTANCE_NAME"
USER_DATA=$(base64 <<EOF
#!/bin/bash
apt update
apt install -y unzip git
hostnamectl set-hostname $HOSTNAME
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


# Instancia para ThinLinc Maestro1
INSTANCE_NAME="ThinLincMaestro1"
PRIVATE_IP="10.0.2.11"

HOSTNAME="$INSTANCE_NAME"
USER_DATA=$(base64 <<EOF
#!/bin/bash
apt update
apt install -y unzip git
hostnamectl set-hostname $HOSTNAME
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


# Instancia para ThinLinc Maestro2
INSTANCE_NAME="ThinLincMaestro2"
PRIVATE_IP="10.0.2.12"

HOSTNAME="$INSTANCE_NAME"
USER_DATA=$(base64 <<EOF
#!/bin/bash
apt update
apt install -y unzip git
hostnamectl set-hostname $HOSTNAME
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
