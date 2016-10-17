#!/usr/bin/env bash

#############################
# Include scripts
#############################
source /bootstrap/functions.sh

#############################
# variables and environment
#############################
get_environment
SQL_SCRIPT=/bootstrap/glance.sql

############################
# CONFIGURE GLANCE
############################
# llamada a la funcion del functions.sh
re_write_file "/controller/glance/glance-api.conf" "/etc/glance/"
re_write_file "/controller/glance/glance-registry.conf" "/etc/glance/"

# Change glance DB password in the SQL script based on what we have in environment
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



if ! does_db_exist glance; then

    # create database
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -h $MYSQL_HOST <$SQL_SCRIPT

    # sync the database
    glance-manage db_sync

    # configure openstack client 
cat >~/openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_AUTH_URL=$OS_URL
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_INTERFACE=admin
EOF

    source ~/openrc
    
    # Get OS_TOKEN from environment 
    export OS_TOKEN=$ADMIN_TOKEN
    export OS_PROJECT_NAME=admin
    export OS_USERNAME=admin
    export OS_PASSWORD=$ADMIN_PASSWORD

    openstack service create  --name glance --description "Openstack Image Service" image
    sleep 3; openstack endpoint create --region $REGION image public http://$GLANCE_HOSTNAME:9292
    sleep 3; openstack endpoint create --region $REGION image internal http://$GLANCE_HOSTNAME:9292
    sleep 3; openstack endpoint create --region $REGION image admin http://$GLANCE_HOSTNAME:9292
    sleep 3; openstack user create --domain default --password $GLANCE_PASSWORD $GLANCE_USERNAME
    sleep 3; openstack role add --project services --user glance admin

fi

# Add the rest to the openrc as appropriate

cat >>~/openrc <<EOF
export OS_PROJECT_NAME=services
export OS_USERNAME=$GLANCE_USERNAME
export OS_PASSWORD=$GLANCE_PASSWORD
EOF



# start glance service
glance-registry &
sleep 5
glance-api
