#!/usr/bin/env bash

ETCD_HOSTIP=172.16.254.3
ETCD="http://$ETCD_HOSTIP:2379/v2/keys"

TOPDIR=/bootstrap


#### First, read the general (global) variables from "00-general/environment.conf" 

source <(cat $TOPDIR/00-general/environment.conf | sed -e s~general/~export\ ~g)


#### Load everything into etcd. The variables from "environment.conf" will be expanded to their respective values read above. 

# Clean etcd up first
curl  -X DELETE "$ETCD/controller?recursive=true"
curl  -X DELETE "$ETCD/general?recursive=true"
curl  -X DELETE "$ETCD/compute?recursive=true"

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
