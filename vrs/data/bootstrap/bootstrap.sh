#!/usr/bin/env bash

#############################
# Include scripts
#############################
source /bootstrap/functions.sh

#############################
# variables and environment
#############################
get_environment


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

#### In case the VRS need to be restarted inside the container -- instead via K8S. Which is _highly_ recommended if we don't want to use the local OVSDB....

/bin/sleep 1d
