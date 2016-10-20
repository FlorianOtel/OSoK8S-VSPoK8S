#!/usr/bin/env bash

#############################
# Include scripts
#############################
source /bootstrap/functions.sh

#############################
# variables and environment
#############################
get_environment

apache2ctl -DFOREGROUND

/bin/sleep 1d
