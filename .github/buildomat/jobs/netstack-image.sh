#!/bin/bash
# This script is used to build the netstack image
# It can be ran locally or in CI
#:
#: name = "netstack-image"
#: variety = "basic"
#: target = "helios"
#: rust_toolchain = "nightly"
#: output_rules = [
#:   "=/out/netstack.xz",
#:   "=/out/version.txt",
#:   "=/out/netstack.sha256",
#:   "=/out/netstack.xz.sha256",
#: ]
#:
#: access_repos = [
#:   "oxidecomputer/helios-engvm",
#: ]
#:
#: [[publish]]
#: series = "image"
#: name = "netstack.xz"
#: from_output = "/out/netstack.xz"
#:
#: [[publish]]
#: series = "image"
#: name = "version.txt"
#: from_output = "/out/version.txt"
#:
#: [[publish]]
#: series = "image"
#: name = "netstack.sha256"
#: from_output = "/out/netstack.sha256"
#:
#: [[publish]]
#: series = "image"
#: name = "netstack.xz.sha256"
#: from_output = "/out/netstack.xz.sha256"
#:

set -e
set -o pipefail
set -o xtrace

IMAGE_NAME=netstack
export VARIANT=netstack
export MACHINE=propolis

# We need the helios-engvm tooling to build our image. Masaka branch has
# some special goodies added that are needed for netstack
if [[ ! -d helios-engvm ]]; then
    git clone --branch masaka git@github.com:oxidecomputer/helios-engvm.git
fi

pushd helios-engvm/image

pfexec ../../falcon-bits.sh
pfexec ../../netstack-bits.sh

# TODO remove this once the p5p branch is merged into upstream
if [[ ! -d image-builder ]]; then
    git clone --branch p5p git@github.com:rcgoodfellow/image-builder.git
fi

./setup.sh
./strap.sh
./image.sh

popd

pfexec mkdir -p /out
pfexec chown -R "$UID" /out
cp version.txt /out/version.txt
cp /rpool/images/output/helios-propolis-ttya-netstack.raw /out/$IMAGE_NAME
sha256sum /out/$IMAGE_NAME > /out/$IMAGE_NAME.sha256
xz -vv /out/$IMAGE_NAME
sha256sum /out/$IMAGE_NAME.xz > /out/$IMAGE_NAME.xz.sha256
