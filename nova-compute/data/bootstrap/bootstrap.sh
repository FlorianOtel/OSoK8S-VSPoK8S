#!/usr/bin/env bash

#############################
# Include scripts
#############################
source /bootstrap/functions.sh

#############################
# variables and environment
#############################
get_environment

########
######## Install VRS
########


#### VRS configuration 

MODULES="openvswitch vport_vxlan vport_gre"

export NUAGE_PERSONALITY=vrs
export NUAGE_PLATFORM="kvm"

#### (!?!?!) The "ACTIVE_CONTROLLER" in VRS _has_ to be an IP address, FQDNs don't work.. So we need to resolve the VSC FQDN explicitely :/ .... 

read VSC_IP _ < <(getent hosts $VSC_HOSTNAME)
export NUAGE_ACTIVE_CONTROLLER=$VSC_IP

# export NUAGE_STANDBY_CONTROLLER=
# export NUAGE_MGMT_ETH=
# export NUAGE_UPLINK_ETH=eth0
export NUAGE_CONN_TYPE=tcp
export NUAGE_DEFAULT_BRIDGE=alubr0
export NUAGE_BRIDGE_MTU=1500 
# export NUAGE_CLIENT_KEY_PATH=
# export NUAGE_CLIENT_CERT_PATH=
# export NUAGE_CA_CERT_PATH=

function log {
        echo `date` $ME - $@
}


function checkModules {
    for i in $MODULES; do
        log "[ Checking $i module... ]"
        a="`lsmod | grep $i &>/dev/null; echo $?`"
        if [ $a -gt 0 ]; then
            log "[ Loading $i module... ]"
            modprobe $i
        fi
    done
}

checkModules


fix_configs /etc/default/openvswitch-switch

/etc/init.d/nuage-openvswitch-switch start

######## 
######## Nova compute 
######## 

re_write_file "/compute/nova/nova.conf" "/etc/nova/"
# re_write_file "/controller/neutron/neutron.conf" "/etc/neutron/"


# Fix "/etc/default/nuage-metadata-agent"
fix_configs /etc/default/nuage-metadata-agent


export MY_IP=`hostname -i` 
echo "===> MY_IP is: $MY_IP"

sed -i "s!^my_ip.*=.*!my_ip = $MY_IP!" /etc/nova/nova.conf
sed -i "s!^#metadata_host.*=.*!metadata_host = $MY_IP!" /etc/nova/nova.conf




cat >~/openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_AUTH_URL=$OS_URL
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_INTERFACE=internal
export OS_PROJECT_NAME=services
export OS_USERNAME=$NOVA_USERNAME
export OS_PASSWORD=$NOVA_PASSWORD
EOF

source ~/openrc


# Fix the rest of ~/openrc properly. We do the whole file in case the DB was already created (restarting the pod)  




#### 

mkdir /var/run/dbus/
mkdir /usr/local/lib/python2.7/dist-packages/instances
mkdir -p /var/lib/nova/instances
chmod o+x /var/lib/nova/instances
chown root:kvm /dev/kvm
chmod 666 /dev/kvm

/etc/init.d/libvirt-bin start

dbus-daemon --config-file=/etc/dbus-1/system.conf &

# /usr/share/openvswitch/scripts/nuage-metadata-agent.init start

nova-compute --config-file=/etc/nova/nova.conf


/bin/sleep 1d
