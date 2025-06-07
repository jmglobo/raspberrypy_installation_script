#!/bin/bash

#============================================== #
# PROGRAMS EXECUTION SCRIPT #
#============================================== #

# Configuration variables definition
NAS_IP=''               # NAS IP
USER=''                 # System user
NAS_MOUNT_DIR=''        # NAS mount directory (e.g., /home/$USER/nas_$USER)
NOTIFICATIONS_SCRIPT=''  # Path to the notifications script
WIREGUARD_CONTAINER=''   # WireGuard container name
ZABBIX_DB_CONTAINER=''   # Zabbix database container name
ZABBIX_SERVER_CONTAINER='' # Zabbix server container name
ZABBIX_FRONT_CONTAINER=''  # Zabbix front container name
ZABBIX_HOSTS_CONTAINER=''  # Zabbix hosts communications container name
ZABBIX_AGENT_CONTAINER=''  # Zabbix agent container name
POSTGRESQL_CONTAINER=''   # PostgreSQL container name
ODOO_CONTAINER=''         # Odoo container name
BOT_NOTIFICATIONS_CONTAINER='' # Bot_Machines_Notifications_interface container name

# WIREGUARD CONTAINER
#--------------------
sleep 1
sudo docker start $WIREGUARD_CONTAINER

# ZABBIX CONTAINERS
#------------------
sleep 1
sudo docker start $ZABBIX_DB_CONTAINER
sudo docker start $ZABBIX_SERVER_CONTAINER
sudo docker start $ZABBIX_FRONT_CONTAINER
sudo docker start $ZABBIX_HOSTS_CONTAINER
sudo docker start $ZABBIX_AGENT_CONTAINER

# POSTGRESQL CONTAINER
#---------------------
sleep 1
sudo docker start $POSTGRESQL_CONTAINER

# ODOO CONTAINER
#---------------
sleep 1
sudo docker start $ODOO_CONTAINER

# BOT_MACHINES_NOTIFICATIONS_INTERFACE CONTAINER
#----------------------------------------------
sleep 1
sudo docker start $BOT_NOTIFICATIONS_CONTAINER

# CHECK NAS CONNECTION AND STATUS REPORT
#---------------------------------------
echo "Checking NAS connection..."
nas_connection_result=$(ping -c 1 $NAS_IP | grep -o "1 received")
if [ "$nas_connection_result" == "1 received" ]; then
    nas_connection_message="The device is connected to the NAS."
else
    nas_connection_message="The device is not connected to the NAS."
fi

# FINAL REBOOT MESSAGE AND SERVICE ACTIVATION REPORT
#--------------------------------------------------
if pip3 list | grep -q -i "requests"; then
    :
else
    echo "Installing requests package for Python..."
    pip3 install requests
fi
private_ip=$(hostname -I | cut -d ' ' -f 1)
public_ip=$(curl -4 ifconfig.co)
final_message="The device has started and all services are operational. Private IP address is $private_ip. Public IP address is $public_ip. $nas_connection_message"
echo "$final_message" | python3 $NOTIFICATIONS_SCRIPT
