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

#
# Configure OPTE
#
banner "opte"
/opt/oxide/opte/bin/opteadm set-xde-underlay vioif0 vioif1

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
chmod +x /opt/cargo-bay/maghemite/ddmadm
/opt/cargo-bay/maghemite/ddmd 8000 ::1 vioif0/v6 vioif1/v6 transit --dendrite &
sleep 5

#
# Configure underlay
#
banner "underlay"
ipadm create-addr -T static -a "192.168.100.$NODE_NUM" vioif2/v4
route add default "192.168.100.100"

#
# Start data plane daemon
#
banner "dpd"
chmod +x /opt/cargo-bay/dendrite/dpd
/opt/cargo-bay/dendrite/dpd --domain none &

#
# Setup softnpu
#
banner "softnpu"
chmod +x /opt/cargo-bay/softnpuadm/softnpuadm
/opt/cargo-bay/softnpuadm/softnpuadm load-program /opt/cargo-bay/p4/libsidecar_lite.so
/opt/cargo-bay/softnpuadm/softnpuadm add-address6 fe80::aae1:deff:fe01:701b
/opt/cargo-bay/softnpuadm/softnpuadm add-address6 fe80::aae1:deff:fe01:701c

#
# Start dsyncd
#
banner "dsyncd"
chmod +x /opt/cargo-bay/dendrite/dsyncd
/opt/cargo-bay/dendrite/dsyncd --port 12224 &
