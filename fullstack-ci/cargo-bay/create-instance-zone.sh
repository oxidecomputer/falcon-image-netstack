#!/bin/bash

set -e
set -m
set -o pipefail
set -o xtrace

#
# Check for node number used to generate addresses
# This should be the node that the guest (zone) is running on
#
if [[ ! -v NODE_NUM ]]; then
    echo "NODE_NUM is not set"
    exit 1
fi

#
# Check for guest number used to generate addresses
#
if [[ ! -v GUEST_NUM ]]; then
    echo "GUEST_NUM is not set"
    exit 1
fi

vnic="vnic$GUEST_NUM"
zone="iz$GUEST_NUM"

name="xde$GUEST_NUM"
instance_ip="10.0.0.$GUEST_NUM"
instance_mac="A8:40:25:ff:00:0$GUEST_NUM"
gateway_mac=A8:40:25:00:00:01
gateway_ip=10.0.0.254
boundary_services_addr=fd00:99::1
boundary_services_vni=99
vpc_vni=10
vpc_subnet=10.0.0.0/24
source_underlay_addr="fd00:$NODE_NUM::1"

snat_start="$GUEST_NUM"000
snat_end="$GUEST_NUM"999
snat_ip=10.100.1.10
snat_gw_mac=a8:e1:de:00:02:01 # this is not meaningful

/opt/oxide/opte/bin/opteadm create-xde \
"$name" \
--private-mac "$instance_mac" \
--private-ip "$instance_ip" \
--gateway-mac "$gateway_mac" \
--gateway-ip "$gateway_ip" \
--bsvc-addr "$boundary_services_addr" \
--bsvc-vni "$boundary_services_vni" \
--vpc-vni "$vpc_vni" \
--vpc-subnet "$vpc_subnet" \
--src-underlay-addr "$source_underlay_addr" \
--snat-start "$snat_start" \
--snat-end "$snat_end" \
--snat-ip "$snat_ip" \
--snat-gw-mac "$snat_gw_mac"

dladm create-vnic -t -l "$name" -m "$instance_mac" "$vnic"

/opt/oxide/opte/bin/opteadm add-router-entry-ipv4 \
-p "$name" \
10.0.0.0/24 \
sub4=10.0.0.0/24

/opt/oxide/opte/bin/opteadm add-router-entry-ipv4 -p "$name" '0.0.0.0/0' ig

zfs create -p -o mountpoint=/instance-test-zones rpool/instance-test-zones
pkg set-publisher --search-first helios-dev

cat <<EOF > instance-zone-"$GUEST_NUM".txt
create
set brand=sparse
set zonepath=/instance-test-zones/$zone
set ip-type=exclusive
set autoboot=false
add net
    set physical=$vnic
end
add attr
    set name=resolvers
    set type=string
    set value=1.1.1.1,1.0.0.1
end
commit
EOF

cat <<EOF > init-zone-"$zone".sh
set -x

# wait for network
while [[ `svcs -Ho STATE network` != "online" ]]; do
  sleep 1
done

# add the source address for this instance
ipadm create-addr -t -T static -a $instance_ip/32 $vnic/v4

# add an on-link route to the gateway sourced from the instance address
route add $gateway_ip $instance_ip -interface

# set the default route to go through the gateway
route add default $gateway_ip
EOF

chmod +x init-zone-"$zone".sh

zonecfg -z "$zone" -f instance-zone-"$GUEST_NUM".txt
zoneadm -z "$zone" install
zoneadm -z "$zone" boot
 
sleep 20

zlogin "$zone" bash -s < init-zone-"$zone".sh
