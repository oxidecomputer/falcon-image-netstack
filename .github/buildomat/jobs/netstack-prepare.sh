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
#:   "oxidecomputer/dendrite",
#:   "oxidecomputer/p4",
#:   "oxidecomputer/testbed",
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


topdir=$(pwd)

#
# Install required build tooling
#
pfexec pkg install pkg:/ooce/developer/clang-120@12.0.0-1.0

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
cargo build --features falcon --release
mkdir -p "$topdir/bin/propolis"
cp target/release/lib* "$topdir/bin/propolis"
cp target/release/propolis-cli* "$topdir/bin/propolis"
cp target/release/propolis-server* "$topdir/bin/propolis"
cp target/release/propolis-standalone* "$topdir/bin/propolis"
cargo clean
popd

pushd propolis/softnpuadm
cargo build --release
mkdir -p "$topdir/fullstack-ci/cargo-bay/softnpuadm"
cp ../target/release/softnpuadm "$topdir/fullstack-ci/cargo-bay/softnpuadm"
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
cargo build --release
mkdir -p "$topdir/fullstack-ci/cargo-bay/p4"
cp target/release/lib* "$topdir/fullstack-ci/cargo-bay/p4"
cp target/release/p4* "$topdir/fullstack-ci/cargo-bay/p4"
cp target/release/x4c* "$topdir/fullstack-ci/cargo-bay/p4"
cargo clean
popd

#
# Clone the dendrite repo
# We need to build a custom branch of dendrite in order to use softnpu
# ASIC emulation
#
if [[ ! -d dendrite ]]; then
    git clone --branch softnpu https://github.com/oxidecomputer/dendrite.git
fi

pushd dendrite
cargo build --features softnpu --release
mkdir -p "$topdir/fullstack-ci/cargo-bay/dendrite"
cp target/release/lib* "$topdir/fullstack-ci/cargo-bay/dendrite"
cp target/release/dpd "$topdir/fullstack-ci/cargo-bay/dendrite"
cp target/release/dsyncd "$topdir/fullstack-ci/cargo-bay/dendrite"
cp target/release/protod "$topdir/fullstack-ci/cargo-bay/dendrite"
cp target/release/swadm "$topdir/fullstack-ci/cargo-bay/dendrite"
cp target/release/tests "$topdir/fullstack-ci/cargo-bay/dendrite"
cp target/release/xtask "$topdir/fullstack-ci/cargo-bay/dendrite"
cargo clean
popd


#
# Build the halfstack-2x2-ci falcon topology binary for use in our next CI task
#
pushd fullstack-ci
cargo build --release
cp target/release/fullstack-ci "$topdir/bin/"
cargo clean
popd

#
# Bundle everything up for use in the next CI task
#
pfexec mkdir -p /out
pfexec chown -R "$UID" /out
cd ..
tar -cf - falcon-image-netstack | xz -T 0 -9 -vv -c - > /out/build-tools.tar.xz
