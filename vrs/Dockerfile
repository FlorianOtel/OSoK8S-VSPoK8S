#### This is assumed to be Ubuntu 14.04

FROM ubuntu-base-os

MAINTAINER Eurocloud

ADD     data /

# Install VRS
RUN apt-get -y update && \
    dpkg -i /Nuage-VSP/4.0R4/nuage-openvswitch-common_4.0.4-45_all.deb  /Nuage-VSP/4.0R4/nuage-openvswitch-switch_4.0.4-45_amd64.deb /Nuage-VSP/4.0R4/nuage-python-openvswitch_4.0.4-45_all.deb ; exit 0 

RUN apt-get -fy install &&\
    chown root:root /bootstrap/*.sh && chmod a+x /bootstrap/*.sh

ENTRYPOINT  ["/bootstrap/bootstrap.sh"]

