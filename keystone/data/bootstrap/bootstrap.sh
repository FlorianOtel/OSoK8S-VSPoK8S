#!/usr/bin/env bash

#############################
# Include scripts
#############################
source /bootstrap/functions.sh

#############################
# variables and environment
#############################
get_environment
SQL_SCRIPT=/bootstrap/keystone.sql

############################
# CONFIGURE KEYSTONE
############################
# llamada a la funcion del functions.sh
re_write_file "/controller/keystone/keystone.conf" "/etc/keystone/"

# Change keystone DB password in the SQL script based on what we have in environment 
fix_configs $SQL_SCRIPT

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


if ! does_db_exist keystone; then

    # create database keystone
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -h $MYSQL_HOST <$SQL_SCRIPT
    # Populate the Identity service database
    keystone-manage db_sync

    # Initialize Fernet keys
    mkdir -p /etc/keystone/fernet-keys
    chmod 0750 /etc/keystone/fernet-keys/

    # echo "xRFeIEUineSD9EnHlraby90RAxIkekN_ZdGNhdZ2u3M=">/etc/keystone/fernet-keys/0
    # echo "BLy_nPN2ekT0DrfFWOwxW6FpQUuu5FTrGb--cbdcPYo="

    keystone-manage fernet_setup --keystone-user root --keystone-group root
    # mv /etc/keystone/default_catalog.templates /etc/keystone/default_catalog

    # start keystone service and wait
    uwsgi --http 0.0.0.0:35357 --wsgi-file $(which keystone-wsgi-admin) &
    sleep 5

    # Initialize account
    ### These commands rely on OS_TOKEN and OS_URL env. variables 

    export OS_TOKEN=$ADMIN_TOKEN

    openstack service create  --name keystone --description "Openstack Identity" identity
    openstack endpoint create --region $REGION identity public https://$KEYSTONE_OFUSCADO/v3
    openstack endpoint create --region $REGION identity internal http://$KEYSTONE_HOSTNAME:5000/v3
    openstack endpoint create --region $REGION identity admin http://$KEYSTONE_HOSTNAME:35357/v3
    openstack domain create --description "Default Domain" default
    openstack project create --domain default  --description "Admin Project" admin
    openstack project create --domain default  --description "Service Project" services
    openstack user create --domain default --password $ADMIN_PASSWORD admin
    openstack role create admin
    openstack role create user
    openstack role add --project admin --user admin admin

    ### unset $OS_TOKEN $OS_URL
fi

#############################
# Write openrc to disk
#############################
cat >~/openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASSWORD
export OS_AUTH_URL=$OS_URL
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_INTERFACE=admin
EOF

cat ~/openrc

#############################
# reboot services
#############################
pkill uwsgi
sleep 5
uwsgi --http 0.0.0.0:5000 --wsgi-file $(which keystone-wsgi-public) &
sleep 5
uwsgi --http 0.0.0.0:35357 --wsgi-file $(which keystone-wsgi-admin)

