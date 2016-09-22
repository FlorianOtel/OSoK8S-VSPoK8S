FROM ubuntu-base-os
MAINTAINER BBVA Innovation <eurocloud-oneteam.group@bbva.com>

ADD     data /

ENV DEBIAN_FRONTEND=noninteractive

RUN	apt-get -y update && \
        apt-get install -y --no-install-recommends  qemu-kvm qemu-utils libvirt-bin bridge-utils iproute2 telnet screen ipset libguestfs-tools linux-image-generic &&\
	update-guestfs-appliance

# HACK around https://github.com/dotcloud/docker/issues/5490 -- being able to run 'tcpdump' inside a privileged docker container. 
RUN mv /usr/sbin/tcpdump /usr/bin/tcpdump


#### #  Nuage specific options for KVM
#### RUN echo "options kvm_intel ept=0" > /etc/modprobe.d/nuage_kvm_intel.conf
#### ENV AUTO_ATTACH='yes' \
####     KVM_CPU_OPTS='-m 4051 -smp 4,sockets=4,cores=1,threads=1'
#### 
#### CMD ["-smbios", "type=1,product=TIMOS"]


ENTRYPOINT  ["/bootstrap/bootstrap.sh"]

