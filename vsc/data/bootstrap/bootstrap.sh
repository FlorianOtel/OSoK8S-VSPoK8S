#!/usr/bin/env bash

#############################
# Include scripts
#############################
source /bootstrap/functions.sh

#############################
# variables and environment
#############################
get_environment

# Get my IPv4 address (including netmask) 
read _ MY_IP _  < <(ip addr show eth0 | grep "inet ")

# Get the local GW 
read _ _ MY_GW _ < <(ip route list match 0/0)

# Get my DNS server. When using K8S this is set at runtime in "/etc/resolv.conf" 
read _ MY_DNS  < <(cat /etc/resolv.conf | grep nameserver)

### REMOVE ME -- Override: When on GCE, need to use a different DNS server & forwarder that can resolve the local VSD hostname
MY_DNS=172.16.1.254


MY_HOSTNAME=`hostname`

export MY_IP
export MY_GW
export MY_DNS
export MY_HOSTNAME

guestmount -a /image/vsc_singledisk_v40r4.qcow2 -m /dev/sda1  /mnt

# Fix the VSC config files 
fix_configs /bootstrap/*.cfg 

cp -f /bootstrap/*.cfg /mnt

### (!!!) The "bof.cfg" _must_ be world-wide executable but "config.cfg" _not_ 
chmod 0755 /mnt/bof.cfg
chmod 0644 /mnt/config.cfg

guestunmount /mnt

echo "===> VSC configuration file <==="
cat /bootstrap/config.cfg


brctl addbr virbr0


# brctl addbr virbr1
# brctl addif virbr1 eth0

cat <<EOF  >/etc/qemu/bridge.conf
allow virbr0
EOF


#### (!!!) Create macvtap interface -- we will use this for the 2nd iface of the VSC (control interface). For the first interface we still use standard "tap" to "virbr0" LB.
ip link add link eth0 name macvtap0 type macvtap mode bridge


#### Steal the MAC address of eth0. WE need to do this since in some cases -- e.g. Nuage VSP -- the MAC address is tied to the port. 
ETH0_MAC=`cat /sys/class/net/eth0/address`
MACVTAP0_MAC=`cat /sys/class/net/macvtap0/address`

echo "===> eth0 MAC address is: $ETH0_MAC"
echo "===> macvtap0 MAC address is: $MACVTAP0_MAC"

ip link set dev eth0 down
ip link set dev macvtap0 address $ETH0_MAC
ip link set dev eth0 address $MACVTAP0_MAC
ip link set dev eth0 up 

####  Steal the IP address and assign it to "macvtap0". (!!!) Same IP address will be then re-used inside the VSC as the controll interface (the guest side of "macvtap0" 
ifconfig eth0 0.0.0.0
ifconfig macvtap0 $MY_IP
# Restore default GW
route add default gw $MY_GW


#### (!!!) In order to use "macvtap0" in QEMU inside docker we need to create the right device inside the container (running privileged). 

IFS=':'
read MAJOR MINOR < <(cat /sys/devices/virtual/net/macvtap0/tap*/dev)
mknod /dev/tap-vm c ${MAJOR} ${MINOR}
# restore IFS 
unset IFS 


#### Start the VSC VM. (?!?!) Even for the macvtap device we need to use "virtio-net-pci" device, not "virtio" (?!?!). Source: 

echo "===> Starting the VSC ..." 


/usr/bin/qemu-system-x86_64 -name vsc1-v40r4 -machine pc-1.0,accel=tcg,usb=off -m 4051 -realtime mlock=off   -smp 1,sockets=1,cores=1,threads=1 -smbios type=1,product=Nuage_VSC -nographic -no-user-config -nodefaults  -rtc base=utc -no-shutdown -no-acpi -boot strict=on -drive file=/image/vsc_singledisk_v40r4.qcow2,if=none,id=drive-ide0-0-0,format=qcow2,cache=writethrough -device ide-hd,bus=ide.0,unit=0,drive=drive-ide0-0-0,id=ide0-0-0,bootindex=1 -device virtio-balloon-pci,id=balloon0  -netdev bridge,br=virbr0,id=hostnet0 -device virtio-net-pci,netdev=hostnet0,id=net0,mac=52:54:00:06:01:9d -chardev pty,id=charserial0 -device isa-serial,chardev=charserial0,id=serial0 -device virtio-net-pci,netdev=macvtap,mac=$(< /sys/class/net/macvtap0/address) -netdev tap,id=macvtap,vhost=on,fd=3 3<>/dev/tap-vm

# Same, but w/o serial console <---> without the the need to mount "/dev/pts" from the host / create pseudo-terminals in the container to access console 
# /usr/bin/qemu-system-x86_64 -name vsc1-v40r4 -machine pc-1.0,accel=tcg,usb=off -m 4051 -realtime mlock=off   -smp 1,sockets=1,cores=1,threads=1 -smbios type=1,product=Nuage_VSC -nographic -no-user-config -nodefaults  -rtc base=utc -no-shutdown -no-acpi -boot strict=on -drive file=/image/vsc_singledisk_v40r4.qcow2,if=none,id=drive-ide0-0-0,format=qcow2,cache=writethrough -device ide-hd,bus=ide.0,unit=0,drive=drive-ide0-0-0,id=ide0-0-0,bootindex=1 -device virtio-balloon-pci,id=balloon0  -netdev bridge,br=virbr0,id=hostnet0 -device virtio-net-pci,netdev=hostnet0,id=net0,mac=52:54:00:06:01:9d -device virtio-net-pci,netdev=macvtap,mac=$(< /sys/class/net/macvtap0/address) -netdev tap,id=macvtap,vhost=on,fd=3 3<>/dev/tap-vm


#### Old: using "virbr0" and "virbr1" and tap interfaces. Convoluted since we need to route interfaces or 1-1 NAT etc. 

# /usr/bin/qemu-system-x86_64 -name vsc1-v40r4 -machine pc-1.0,accel=tcg,usb=off -m 4051 -realtime mlock=off   -smp 1,sockets=1,cores=1,threads=1 -smbios type=1,product=Nuage_VSC -nographic -no-user-config -nodefaults  -rtc base=utc -no-shutdown -no-acpi -boot strict=on -drive file=/image/vsc_singledisk_v40r4.qcow2,if=none,id=drive-ide0-0-0,format=qcow2,cache=writethrough -device ide-hd,bus=ide.0,unit=0,drive=drive-ide0-0-0,id=ide0-0-0,bootindex=1 -device virtio-balloon-pci,id=balloon0  -netdev bridge,br=virbr0,id=hostnet0 -device virtio-net-pci,netdev=hostnet0,id=net0,mac=52:54:00:06:01:9d -netdev bridge,br=virbr1,id=hostnet1 -device virtio-net-pci,netdev=hostnet1,id=net1,mac=52:54:00:45:d2:69 -chardev pty,id=charserial0 -device isa-serial,chardev=charserial0,id=serial0 

#### # Same, but w/o serial console -- and the need to mount "/dev/pts" from the host / create pseudo-terminals in the container 
#### /usr/bin/qemu-system-x86_64 -name vsc1-v40r4 -machine pc-1.0,accel=tcg,usb=off -m 4051 -realtime mlock=off   -smp 1,sockets=1,cores=1,threads=1 -smbios type=1,product=Nuage_VSC -nographic -no-user-config -nodefaults  -rtc base=utc -no-shutdown -no-acpi -boot strict=on -drive file=/image/vsc_singledisk_v40r4.qcow2,if=none,id=drive-ide0-0-0,format=qcow2,cache=writethrough -device ide-hd,bus=ide.0,unit=0,drive=drive-ide0-0-0,id=ide0-0-0,bootindex=1 -device virtio-balloon-pci,id=balloon0  -netdev bridge,br=virbr0,id=hostnet0 -device virtio-net-pci,netdev=hostnet0,id=net0,mac=52:54:00:06:01:9d -netdev bridge,br=virbr1,id=hostnet1 -device virtio-net-pci,netdev=hostnet1,id=net1,mac=52:54:00:45:d2:69 

