#!/bin/bash

set -e
set -m
set -o pipefail
set -o xtrace

#
# Check for node number used to generate addresses
#
if [[ ! -v NODE_NUM ]]; then
    echo "NODE_NUM is not set"
    exit 1
fi

#
# Display kernel information
#
banner "kernel"
uname -a
cat /etc/versions/build

#
# DNS configuration
#
banner "dns"
echo "nameserver 8.8.8.8" > /etc/resolv.conf

#
# Configure interfaces
#
banner "interfaces"
ipadm create-addr -T addrconf vioif0/v6
ipadm create-addr -T addrconf vioif1/v6
ipadm create-addr -T static -a 10.100.102.2/24 vioif2/v4
ipadm create-addr -T static -a fd00:99::1/128 lo0/boundsvcs

#
# Out of band interface
#
banner "oob"
ipadm create-addr -T static -a "192.168.100.$NODE_NUM" vioif3/v4
route add default "192.168.100.100"

banner "scrimlet"
#
# Configure router (maghemite)
#
banner "maghemite"
#
# TODO uncomment once development branch of maghemite is merged and new image is
# released.
#
# svccfg -s mg-ddm setprop config/log=debug
# svccfg -s mg-ddm setprop config/interfaces = astring: '("vioif0/v6" "vioif1/v6")'
# svcadm enable mg-ddm
#
chmod +x /opt/cargo-bay/maghemite/ddmd
cp /opt/cargo-bay/maghemite/ddmd /bin/

chmod +x /opt/cargo-bay/maghemite/ddmadm
cp /opt/cargo-bay/maghemite/ddmadm /bin/

ddmd 8000 ::1 vioif0/v6 vioif1/v6 transit --dendrite &
sleep 5

ddmadm advertise-prefix "fd00:99::1/128"

#
# Start data plane daemon
#
banner "dpd"
chmod +x /opt/cargo-bay/dendrite/dpd
cp /opt/cargo-bay/dendrite/dpd /bin/

dpd --domain none &

#
# Start dsyncd
#
banner "dsyncd"
chmod +x /opt/cargo-bay/dendrite/dsyncd
cp /opt/cargo-bay/dendrite/dsyncd /bin/

dsyncd --port 12224 &

#
# Setup softnpu
#
banner "softnpu"
chmod +x /opt/cargo-bay/softnpuadm/softnpuadm
cp /opt/cargo-bay/softnpuadm/softnpuadm /bin/

softnpuadm load-program /opt/cargo-bay/p4/libsidecar_lite.so
softnpuadm add-address6 fe80::aae1:deff:fe01:701c
softnpuadm add-address6 fe80::aae1:deff:fe01:701d
softnpuadm add-address6 fd00:99::1

#
# Default route to gateway
#
softnpuadm add-route4 0.0.0.0 0 3 10.100.102.1

#
# Static arp entry for gateway mac address
#
softnpuadm add-arp-entry 10.100.102.1 a8:e1:de:00:02:02

#
# Nat mappings
#

# sled1 guest iz1
softnpuadm add-nat4 10.100.1.10 1000 1999 fd00:1::1 10 a8:40:25:ff:00:01

# sled2 guest iz2
softnpuadm add-nat4 10.100.1.10 2000 2999 fd00:2::1 10 a8:40:25:ff:00:02

# sled3 guest iz3
softnpuadm add-nat4 10.100.1.10 3000 3999 fd00:1::1 10 a8:40:25:ff:00:03
