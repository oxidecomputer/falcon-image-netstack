#!/bin/bash

set -e
set -m
set -o pipefail
set -o xtrace

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
# Transit links from scrimlets to gateway
#
ipadm create-addr -T static -a "10.100.1.1/24" vioif0/v4
ipadm create-addr -T static -a "10.100.2.1/24" vioif1/v4

#
# Interface used to send traffic from Falcon topology to host
#
ipadm create-addr -T static -a "192.168.100.200/24" vioif2/v4

#
# Use address configured on host as default route.
#
route add default "192.168.100.100"

#
# Configure edge router
#
banner "Guest NAT"
# arp -s 192.168.100.10 a8:e1:de:01:70:1e
# arp -s 192.168.100.20 a8:e1:de:01:70:1f
