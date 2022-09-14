#!/bin/bash
# This script is used to validate the netstack image
# It builds a falcon topology using the latest netstack image,
# then tests communication across the simulated network fabric.
#:
#: name = "netstack-validation"
#: variety = "basic"
#: target = "lab"
#: rust_toolchain = "nightly"
#:
#: access_repos = [
#:   "oxidecomputer/testbed",
#: ]
#:
#: skip_clone = true
#:
#: [dependencies.image]
#: job = "netstack-image"
#
#: [dependencies.build]
#: job = "netstack-prepare"
#

set -e
set -m
set -o pipefail
set -o xtrace

export RUST_LOG=debug

#
# This function is for convenience, since the falcon scripts rely on
# aliases that are usually present on end-user machines, but not in CI
#
function sha256sum() {
    command shasum -a 256 "$*"
}

export -f sha256sum

#
# Create etherstub for falcon topology to use as its external link
#
dladm show-etherstub falcon_stub0 || pfexec dladm create-etherstub falcon_stub0
dladm show-vnic falcon_vnic0 || pfexec dladm create-vnic -l falcon_stub0 falcon_vnic0

#
# This interface is used for the falcon topology (external link)
# It will be a part of a private network, we will use NAT to
# facilitate communication with the outside world
#
export INTERFACE=falcon_stub0

#
# This interface is used to reach the internet
#
if [[ ! -v EXT_INTERFACE ]]; then
    echo "EXT_INTERFACE has not been set. This will default to igb0."
    export EXT_INTERFACE=igb0
fi

#
# Create a private ip address for the host to use for communication with the
# falcon topology VMs
#
ipadm show-addr falcon_vnic0/internal || pfexec ipadm create-addr -T static -a 192.168.100.100/24 falcon_vnic0/internal

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

echo "map $EXT_INTERFACE 192.168.100.0/24 -> 0/32 portmap tcp/udp 1025:65000" >> ipnat.conf
echo -n "map $EXT_INTERFACE 192.168.100.0/24 -> 0/32 portmap" >> ipnat.conf
pfexec cp ipnat.conf /etc/ipf/ipnat.conf
pfexec ipnat -f /etc/ipf/ipnat.conf

#
# Verify presence of NAT rules
#
pfexec ipnat -l

#
# Extract the tools needed for launching the falcon topology
#
mkdir /tmp/netstack-validation
pushd /tmp/netstack-validation
xzcat /input/build/out/build-tools.tar.xz | tar -xf -

#
# Add jq and halfstack-2x2-ci to our PATH
#
pushd falcon-image-netstack
export PATH="$(pwd)/bin:$PATH"

# TODO remove
ls -lah bin

pushd falcon

#
# Install tooling and images needed for the falcon topology
#
./get-ovmf.sh

#
# Create the zpool used for extracting our falcon topology images
#
pfexec zpool create -f netstack-validation c1t1d0
export FALCON_DATASET=netstack-validation/falcon

#
# Extract new image into zpool
#
VERSION=$(cat /input/image/out/version.txt)
IMAGE_NAME=netstack
export IMAGE=${VERSION%_*}

echo "extracting image"
unxz -T 0 -c -vv "/input/image/out/$IMAGE_NAME.xz" > "$VERSION.raw"
ls -lah
# sha256sum --status -c "/input/image/out/$IMAGE_NAME.sha256"

echo "Creating ZFS volume $IMAGE"
pfexec zfs create -p -V 20G "$FALCON_DATASET/img/$IMAGE"
echo "Copying contents of image $VERSION into volume"
pfexec dd if=$VERSION.raw of="/dev/zvol/dsk/$FALCON_DATASET/img/$IMAGE" conv=sync
echo "Creating base image snapshot"
pfexec zfs snapshot "$FALCON_DATASET/img/$IMAGE@base"

popd

#
# Run the test
#
pushd fullstack-ci
pfexec fullstack-ci launch
