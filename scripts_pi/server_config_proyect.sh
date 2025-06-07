#!/bin/bash

#============================================== #
# INITIAL SERVER CONFIGURATION WITH UBUNTU SERVER #
#============================================== #

# Configuration variables definition
GATEWAY_IP=''           # Router IP
SERVER_IP=''            # Server IP
NAS_IP=''               # NAS IP
DHCP_RANGE=''           # DHCP IP range
FALLBACK_DNS=''         # Fallback DNS
TIMEZONE=''             # Timezone
HOSTNAME=''             # Server hostname
VPN_SUBNET=''           # VPN subnet
DDCLIENT_USERNAME=''    # ddclient username
DDCLIENT_PASSWORD=''    # ddclient password
DDCLIENT_DOMAIN=''      # ddclient domain
USER=''                 # System user
NAS_PATH=''             # NAS volume path
NAS_BRAND=''            # NAS brand
ORIGINAL_IP=''          # Original IP to remove
NAS_MOUNT_DIR=''        # NAS mount directory (e.g., /home/$USER/nas_$USER)
WIREGUARD_DIR=''        # WireGuard Docker directory
ZABBIX_DIR=''           # Zabbix Docker directory
POSTGRESQL_DIR=''       # PostgreSQL Docker directory
ODOO_DIR=''             # Odoo Docker directory
BOT_NOTIFICATIONS_DIR='' # Bot_Machines_Notifications_interface Docker directory
PROGRAMS_SCRIPT_DIR=''   # Directory containing programs.sh

# Reserved IPs
# $GATEWAY_IP = router
# $SERVER_IP = server
# $NAS_IP = nas

# DHCP Range = $DHCP_RANGE

# Language configuration (if needed)
# dpkg-reconfigure locales
# dpkg-reconfigure keyboard-configuration (Right AltGr)

# NFS permissions on the NAS should be set to: Squash = No Mapping

# Transfer the following files to the Ubuntu Server:
#   > server_config.sh

# Switch to root to execute
#   > sudo su

# Run the script
#   > ./server_config.sh

# NETWORK CONFIGURATION
#----------------------
echo "Configuring static IPs with Netplan..."
cat << EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - $SERVER_IP/24
      routes:
        - to: default
          via: $GATEWAY_IP
          metric: 100
      nameservers:
        addresses: [$SERVER_IP, $FALLBACK_DNS]
EOF
netplan --debug apply
echo "Network configuration applied with Netplan"
echo "------------------------------------------------"
sleep 5

# PACKAGE UPDATE AND UPGRADE
#---------------------------
echo "Updating the system..."
apt-get update -y
apt-get upgrade -y
echo "System updated"
echo "------------------------------------------------"
sleep 5

# INSTALLATION OF REQUIRED PACKAGES
#---------------------------------

# Set timezone
timedatectl set-timezone $TIMEZONE

# Install NFS
echo "Installing package: nfs-common for NAS mounting..."
apt-get install nfs-common -y
echo "NFS installed"
echo "------------------------------------------------"
sleep 5

# Install DDCLIENT
echo "Installing package: ddclient for DNS management..."
apt-get install ddclient -y
echo "DDCLIENT installed"
echo "------------------------------------------------"
sleep 5

# Install IPTABLES-PERSISTENT
echo "Installing package: iptables-persistent for persistent iptables rules..."
apt-get install iptables-persistent -y
echo "IPTABLES-PERSISTENT installed"
echo "------------------------------------------------"
sleep 5

# Install pip
echo "Installing package: pip..."
apt-get install python3-pip -y
echo "Pip installed"
echo "------------------------------------------------"
sleep 5

# Install Docker and dependencies
echo "Installing required packages for Docker..."
apt-get install apt-transport-https ca-certificates curl gnupg -y
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install docker-ce docker-ce-cli containerd.io -y
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker --version
docker-compose --version
usermod -aG docker $(whoami)
chmod 666 /var/run/docker.sock
echo "Docker and its dependencies installed"
echo "------------------------------------------------"
sleep 5

# HOSTNAME CONFIGURATION
#----------------------
echo "Configuring hostname..."
hostnamectl set-hostname $HOSTNAME
echo "$SERVER_IP    $HOSTNAME" >> /etc/hosts
echo "Hostname configured"
echo "------------------------------------------------"


# FIREWALL CONFIGURATION WITH IPTABLES
#------------------------------------
echo "Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Allow NAT for VPN traffic
iptables -t nat -A POSTROUTING -s $VPN_SUBNET -o eth0 -j MASQUERADE -m comment --comment "Enable NAT for VPN"
# Save rules
netfilter-persistent save
netfilter-persistent reload
echo "Firewall configured and rules saved"
echo "------------------------------------------------"

# DNS UPDATE CONFIGURATION
#------------------------
echo "Configuring DNS updates with ddclient..."
cat << EOF > /etc/ddclient.conf
protocol=freedns
use=web, web=https://freedns.afraid.org/dynamic/check.php
login=$DDCLIENT_USERNAME
password=$DDCLIENT_PASSWORD
daemon=5m, timeout=10
syslog=yes, ssl=yes
pid=/run/ddclient.pid
$DDCLIENT_DOMAIN
EOF
chmod 600 /etc/ddclient.conf
systemctl enable ddclient
systemctl restart ddclient
echo "DNS update configured"
echo "------------------------------------------------"

# RESTART SYSTEMCTL AND START SERVICES
#------------------------------------
# Reload systemctl daemon to apply configurations
systemctl daemon-reload

# Restart ddclient service (already enabled above)
systemctl restart ddclient
echo "DNS update service restarted"
echo "------------------------------------------------"

# MOUNT NAS
#----------
echo "Configuring NAS mount..."
cd /home/$USER || mkdir -p /home/$USER && cd /home/$USER
mkdir -p $NAS_MOUNT_DIR
chown $USER:$USER $NAS_MOUNT_DIR
chmod 700 $NAS_MOUNT_DIR
echo "$NAS_IP:$NAS_PATH $NAS_MOUNT_DIR nfs _netdev,defaults 0 0" >> /etc/fstab
systemctl daemon-reload
if mount -t nfs $NAS_IP:$NAS_PATH $NAS_MOUNT_DIR; then
    echo "NAS mounted on the server"
else
    echo "Error mounting NAS"
    exit 1
fi
echo "------------------------------------------------"

# SCHEDULE UPDATES
# qualitative analysis and risk assessment
#-----------------
echo "Scheduling automatic updates..."
echo "0 3 1 * * apt update && apt upgrade -y" | crontab -
echo "Automatic update task created"
echo "------------------------------------------------"

# INCLUDE EXECUTION OF programs.sh
#----------------------------------
# Create the service file with heredoc
cat <<EOF > /etc/systemd/system/mount-nas.service
[Unit]
Description=Mount $NAS_BRAND NAS at $NAS_MOUNT_DIR
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStartPre=/bin/chown $USER:$USER $NAS_MOUNT_DIR
ExecStartPre=/bin/chmod 700 $NAS_MOUNT_DIR
ExecStart=/bin/mount -t nfs $NAS_IP:$NAS_PATH $NAS_MOUNT_DIR
ExecStartPost=/bin/chown $USER:$USER $PROGRAMS_SCRIPT_DIR
ExecStartPost=/bin/chmod +x $PROGRAMS_SCRIPT_DIR/programs.sh
ExecStartPost=$PROGRAMS_SCRIPT_DIR/programs.sh
RemainAfterExit=yes
Restart=on-failure
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

# Apply changes to the system
systemctl daemon-reload
systemctl enable mount-nas.service
systemctl start mount-nas.service

# START DOCKER CONTAINERS
#------------------------
echo "Starting Docker containers..."
# WIREGUARD Container
cd $WIREGUARD_DIR
sudo docker-compose up -d

# ZABBIX Container
cd $ZABBIX_DIR
sudo docker-compose up -d

# PostgreSQL Container
cd $POSTGRESQL_DIR
sudo docker-compose up -d

# Odoo Container
cd $ODOO_DIR
sudo docker-compose up -d

# Bot_Machines_Notifications_interface Container
cd $BOT_NOTIFICATIONS_DIR
sudo docker-compose up -d
echo "Docker containers started"
echo "------------------------------------------------"

# Restrict permissions to docker group and root
chown root:docker /var/run/docker.sock
chmod 660 /var/run/docker.sock

# FINAL REPORT, REMOVE ORIGINAL IP, AND REBOOT
#--------------------------------------------
echo "Installation completed. The machine will reboot in 5 seconds."
ip addr del $ORIGINAL_IP/24 dev eth0
sleep 5
history -c
reboot
