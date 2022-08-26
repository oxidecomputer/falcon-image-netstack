#!/bin/bash
# This script is used to prepare the tools used in the
# netstack validation environment
#:
#: name = "netstack-prepare"
#: variety = "basic"
#: target = "helios"
#: rust_toolchain = "nightly"
#:
#: output_rules = [
#:   "=/out/build-tools.tar.xz",
#: ]
#:
#: access_repos = [
#:   "oxidecomputer/testbed",
#: ]
#:
#: [[publish]]
#: series = "tools"
#: name = "build-tools.tar.xz"
#: from_output = "/out/build-tools.tar.xz"
#:
#: [dependencies.build]
#: job = "netstack-image"
#

set -e
set -o pipefail
set -o xtrace

export RUST_LOG=debug

# List the host's interfaces
dladm show-link
topdir=$(pwd)

mkdir bin

pushd bin
curl -OL https://github.com/stedolan/jq/releases/download/jq-1.4/jq-solaris11-64
mv jq-solaris11-64 jq
chmod +x jq
popd

#
# Shim calls to github to force https instead of ssh for cloning
#
if [[ -n $CI ]]; then
    source ./evil-clone-hack.sh
fi

#
# Clone the falcon repo.
# We need the falcon tooling to install the images needed for our falcon
# topologies.
#
if [[ ! -d falcon ]]; then
    git clone https://github.com/oxidecomputer/falcon.git
fi

#
# Clone the testbed repo
# We need the testbed repo because it contains the particular topology we'll be running
# in our CI task
#
if [[ ! -d testbed ]]; then
    git clone https://github.com/oxidecomputer/testbed.git
fi

#
# Build the halfstack-2x2-ci falcon topology binary for use in our next CI task
#
pushd testbed/halfstack-2x2-ci
cargo build
cp ../target/debug/halfstack-2x2-ci "$topdir/bin/"
cargo clean
popd

#
# Bundle everything up for use in the next CI task
#
pfexec mkdir -p /out
pfexec chown -R "$UID" /out
cd ..
tar -cf - falcon-image-netstack | xz -T 0 -9 -vv -c - > /out/build-tools.tar.xz
