#!/usr/bin/env bash

#############################
# Include scripts
#############################
source /bootstrap/functions.sh

#############################
# variables and environment
#############################
get_environment
SQL_SCRIPT=/bootstrap/neutron.sql

############################
# CONFIGURE NEUTRON
############################
# llamada a la funcion del functions.sh
re_write_file "/controller/neutron/neutron.conf" "/etc/neutron/"
# re_write_file "/controller/neutron/nuage_plugin.ini" "/etc/neutron/plugins/"

sleep 2
MY_IP=`hostname -i`
echo "My IP address is: $MY_IP"


# Change neutron DB password in the SQL script based on what we have in environment
fix_configs $SQL_SCRIPT

# Fix configuration files under /etc/neutron
mv /nuage_plugin.ini /etc/neutron/plugins/nuage/nuage_plugin.ini
fix_configs /etc/neutron 

############################
# DATABASE BOOTSTRAP
############################

function does_db_exist {
  local db="${1}"

  local output=$(mysql -uroot -p$MYSQL_ROOT_PASSWORD -h $MYSQL_HOST -s -N -e "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '${db}'" information_schema)
  if [[ -z "${output}" ]]; then
    return 1 # does not exist
  else
    return 0 # exists
  fi
}


if ! does_db_exist neutron; then

    # create database
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -h $MYSQL_HOST <$SQL_SCRIPT

    # configure openstack client
cat >~/openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_AUTH_URL=$OS_URL
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_INTERFACE=internal
EOF

    source ~/openrc

    # get OS_TOKEN from environment
    export OS_TOKEN=$ADMIN_TOKEN
    export OS_PROJECT_NAME=admin
    export OS_USERNAME=admin
    export OS_PASSWORD=$ADMIN_PASSWORD

    openstack service create  --name neutron --description "Openstack Networking" network
    sleep 3; openstack user create --domain default --password $NEUTRON_PASSWORD $NEUTRON_USERNAME
    sleep 3; openstack role add --project services --user neutron admin
    sleep 3; openstack endpoint create --region $REGION network public http://$NEUTRON_HOSTNAME:9696
    sleep 3; openstack endpoint create --region $REGION network internal http://$NEUTRON_HOSTNAME:9696
    sleep 3; openstack endpoint create --region $REGION network admin http://$NEUTRON_HOSTNAME:9696

    # sync the database
    neutron-db-manage --config-file /etc/neutron/neutron.conf  upgrade head


fi

# Fix the rest of ~/openrc for neutron. Re-writing the whole file in case we restart the pod w/o re-creating the database. 

cat >~/openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_AUTH_URL=$OS_URL
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_INTERFACE=internal
export OS_PROJECT_NAME=services
export OS_USERNAME=$NEUTRON_USERNAME
export OS_PASSWORD=$NEUTRON_PASSWORD
EOF


#### Configure Nuage plugin 
tar -xzvf /Nuage-VSP/4.0R4/nuage-openstack-upgrade-4.0.4-43.tar.gz -C /tmp 
python /tmp/set_and_audit_cms.py --neutron-config-file /etc/neutron/neutron.conf --plugin-config-file /etc/neutron/plugins/nuage/nuage_plugin.ini


# Start Neutron server 
neutron-server --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/nuage/nuage_plugin.ini
