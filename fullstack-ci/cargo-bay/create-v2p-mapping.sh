#!/bin/bash

set -e
set -m
set -o pipefail
set -o xtrace

export RUST_LOG=debug

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

/opt/oxide/opte/bin/opteadm set-v2p "10.0.0.$GUEST_NUM" "A8:40:25:ff:00:0$GUEST_NUM" "fd00:$NODE_NUM::1" 10
