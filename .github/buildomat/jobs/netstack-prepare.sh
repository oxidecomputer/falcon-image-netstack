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
#:   "oxidecomputer/p4",
#: ]
#:
#: [[publish]]
#: series = "tools"
#: name = "build-tools.tar.xz"
#: from_output = "/out/build-tools.tar.xz"
#:
#

set -e
set -o pipefail
set -o xtrace

export RUST_LOG=debug

# List the host's interfaces
dladm show-link
topdir=$(pwd)

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
# Clone the softnpu branch of propolis
# We need this so we can build softnpuadm, which is needed for ASIC emulation
# in our scrimlet CI nodes
#
if [[ ! -d propolis ]]; then
    git clone --branch softnpu-dyload https://github.com/oxidecomputer/propolis.git
fi

pushd propolis
cargo build --release
cp target/debug/propolis-cli "$topdir/bin/"
cp target/debug/propolis-server "$topdir/bin/"
cp target/debug/propolis-standalone "$topdir/bin/"
cargo clean
popd

pushd propolis/softnpuadm
cargo build
cp target/debug/softnpuadm "$topdir/bin/"
cargo clean
popd

#
# Clone the p4 repo
# We need the p4 program from this repo for programming softnpu's forwarding logic
#
if [[ ! -d p4 ]]; then
    git clone https://github.com/oxidecomputer/p4.git
fi

pushd p4
cargo build
mkdir -p "$topdir/fullstack-ci/cargo-bay/p4"
cp target/debug/lib* "$topdir/fullstack-ci/cargo-bay/p4"
cp target/debug/p4* "$topdir/fullstack-ci/cargo-bay/p4"
cp target/debug/x4c* "$topdir/fullstack-ci/cargo-bay/p4"
popd

#
# Build the halfstack-2x2-ci falcon topology binary for use in our next CI task
#
pushd fullstack-ci
cargo build
cp target/debug/fullstack-ci "$topdir/bin/"
cargo clean
popd

#
# Bundle everything up for use in the next CI task
#
pfexec mkdir -p /out
pfexec chown -R "$UID" /out
cd ..
tar -cf - falcon-image-netstack | xz -T 0 -9 -vv -c - > /out/build-tools.tar.xz
