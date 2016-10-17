#!/usr/bin/env bash

#############################
# Include scripts
#############################
source /bootstrap/functions.sh

#############################
# variables and environment
#############################
get_environment
SQL_SCRIPT=/bootstrap/nova.sql

############################
# CONFIGURE NOVA
############################
# llamada a la funcion del functions.sh
re_write_file "/controller/nova/nova.conf" "/etc/nova/"
sleep 5

export MY_IP=`hostname -i`
echo "===> MY_IP is: $MY_IP"


sed -i "s!^my_ip.*=.*!my_ip = $MY_IP!" /etc/nova/nova.conf
sed -i "s!^#metadata_host.*=.*!metadata_host = $MY_IP!" /etc/nova/nova.conf

# Change nova DB pasword in the SQL script based on what we have in environment
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



if ! does_db_exist nova; then

    # create database
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -h $MYSQL_HOST <$SQL_SCRIPT

cat >/usr/local/lib/python2.7/dist-packages/nova/db/sqlalchemy/migrate_repo/migrate.cfg <<EOF
[db_settings]
repository_id=nova
version_table=migrate_version
required_dbs=[]
EOF

cat >/usr/local/lib/python2.7/dist-packages/nova/db/sqlalchemy/api_migrations/migrate_repo/migrate.cfg <<EOF
[db_settings]
repository_id=nova_api
version_table=migrate_version
required_dbs=[]
EOF


    # sync the database
    nova-manage db sync
    nova-manage api_db sync


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

    # get OS_TOKEN from environment 
    export OS_TOKEN=$ADMIN_TOKEN
    export OS_USERNAME=admin
    export OS_PASSWORD=$ADMIN_PASSWORD
    export OS_PROJECT_NAME=admin

    openstack service create  --name nova --description "Openstack Compute" compute
    sleep 3; openstack user create --domain default --password $NOVA_PASSWORD $NOVA_USERNAME
    sleep 3; openstack role add --project services --user nova admin
    sleep 3; openstack endpoint create --region $REGION compute public http://$NOVA_HOSTNAME:8774/v2.1/%\(tenant_id\)s
    sleep 3; openstack endpoint create --region $REGION compute internal http://$NOVA_HOSTNAME:8774/v2.1/%\(tenant_id\)s
    sleep 3; openstack endpoint create --region $REGION compute admin http://$NOVA_HOSTNAME:8774/v2.1/%\(tenant_id\)s


fi

# Fix the rest of ~/openrc properly. We do the whole file in case the DB was already created (restarting the pod) 

cat >~/openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_AUTH_URL=$OS_URL
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_INTERFACE=admin
export OS_PROJECT_NAME=services
export OS_USERNAME=$NOVA_USERNAME
export OS_PASSWORD=$NOVA_PASSWORD
EOF


#patch necesario por el bug de paramiko#######
cd /usr/local/lib/python2.7/dist-packages/nova
cp crypto.py crypto.py.bak
patch -p1 < /bootstrap/patch_Paramiko
cd -
##############################################

nova-api &
nova-cert &
nova-consoleauth &
nova-scheduler &
nova-conductor
