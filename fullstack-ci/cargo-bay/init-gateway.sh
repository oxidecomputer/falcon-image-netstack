#!/bin/bash

set -e
set -m
set -o pipefail
set -o xtrace

export RUST_LOG=debug

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
ipadm create-addr -T static -a "10.100.101.1/24" vioif0/v4
ipadm create-addr -T static -a "10.100.102.1/24" vioif1/v4

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
# scrimlet 1 mac address
arp -s 10.100.101.2 a8:e1:de:01:70:1e
# scrimlet 2 mac address
arp -s 10.100.102.2 a8:e1:de:01:70:1f

# multipath guest traffic to both scrimlets
route add 10.100.1.10 10.100.101.2
route add 10.100.1.10 10.100.102.2

#
# Enable packet filtering
#
pfexec ipf -E

#
# Enable ipv4-forwarding on host so VM traffic can be forwarded to EXT_INTERFACE
#
routeadm -e ipv4-forwarding -u

#
# Enable ipfilter (NAT)
#
svcadm enable -s ipfilter

#
# Check status of services
#
svcs -x ipv4-forwarding
svcs -x route
svcs -x ipfilter

#
# Add NAT rules for outbound traffic from our private network
# We must place a configuration file in /etc/ipf/ipnat.conf, otherwise the
# ipfilter service may randomly flush our rules
#
svccfg -s ipfilter:default setprop firewall_config_default/policy = astring: "custom"

if [[ -f ipnat.conf ]]; then
    rm ipnat.conf
fi

echo "map vioif2 10.100.0.0/16 -> 0/32 portmap tcp/udp 1025:65000" >> ipnat.conf
echo -n "map vioif2 10.100.0.0/16 -> 0/32 portmap" >> ipnat.conf
pfexec cp ipnat.conf /etc/ipf/ipnat.conf
pfexec ipnat -f /etc/ipf/ipnat.conf

#
# Verify presence of NAT rules
#
pfexec ipnat -l
