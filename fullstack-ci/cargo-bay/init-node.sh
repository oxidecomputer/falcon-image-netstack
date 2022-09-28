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

NODE_HEX=$(printf '%x' "$NODE_NUM")

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

chmod +x /opt/cargo-bay/maghemite/ddmd
chmod +x /opt/cargo-bay/maghemite/ddmadm
/opt/cargo-bay/maghemite/ddmd 8000 ::1 vioif0/v6 vioif1/v6 server &
sleep 5

#
# Configure underlay
#
banner "underlay"
ipadm create-addr -T static -a "192.168.100.$NODE_NUM" vioif2/v4
route add default "192.168.100.100"

ipadm create-addr -T static -a "fd00:$NODE_HEX::1/64" lo0/underlay
/opt/oxide/mg-ddm/ddmadm advertise-prefix "fd00:$NODE_HEX::/64"

#
# Set permissions for zone creation and test scripts
#
chmod +x /opt/cargo-bay/create-instance-zone.sh
chmod +x /opt/cargo-bay/create-v2p-mapping.sh
chmod +x /opt/cargo-bay/test-overlay.sh
