#!/usr/bin/env bash

ETCD_HOSTIP=172.16.254.9
ETCD="http://$ETCD_HOSTIP:2379/v2/keys"

TOPDIR=/bootstrap


#### First, read the general (global) variables from "00-general/environment.conf" 

source <(cat $TOPDIR/00-general/environment.conf | sed -e s~general/~export\ ~g)


#### Load everything into etcd. The variables from "environment.conf" will be expanded to their respective values read above. 


# Clean etcd up first
etcdctl --debug -C http://$ETCD_HOSTIP:2379 rm --recursive /general
etcdctl --debug -C http://$ETCD_HOSTIP:2379 rm --recursive /controller
etcdctl --debug -C http://$ETCD_HOSTIP:2379 rm --recursive /compute

for dir in $(find $TOPDIR/ -type d)
do
    for conffile in $dir/*.conf $dir/*.ini
    do
        while read line
        do
	        key=`echo $line | awk -F"=" '{print $1}'`
	        value=`echo $line | awk -F"=" '{print $2}'`
		# Expand any of the global variables above in "value" to their respective values 
		value=$(echo $value | envsubst)
	        curl -fs -X PUT "$ETCD/$key" -d value="$value"
        done < $conffile
    done
done
