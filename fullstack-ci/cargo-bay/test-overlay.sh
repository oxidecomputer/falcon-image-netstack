#!/bin/bash

set -e
set -m
set -o pipefail
set -o xtrace

banner "intra-node"
zlogin iz1 'ping 10.0.0.3'

banner "inter-node"
zlogin iz1 'ping 10.0.0.2'

banner "external"
zlogin iz1 'curl -s -I google.com'

echo "overlay ok!"
