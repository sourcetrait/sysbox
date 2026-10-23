#!/usr/bin/bash
set -euo pipefail

hostname="${1:-}"
pubkey="${2:-}"

usage() {
    echo -e "creates a sysbox podman container"
    echo -e "usage: create.bash <hostname> <ssh_key>"
    exit 1
}

if [[ -z "$hostname" || -z "$pubkey" ]]; then
    usage
fi

if [[ "$pubkey" != *.pub ]]; then
    pubkey="${pubkey}.pub"
fi

if [[ -z "$hostname" || ! -f "$pubkey" || ! -s "$pubkey" ]]; then
    echo -e "error: pubkey not found: $pubkey"
    exit 1
fi

name="$hostname"
volume="${hostname}-home"

#podman create --systemd=always --name $name --hostname $hostname --volume $volume:/home/box --volume /tmp localhost/sysbox

#podman start $hostname 1>/dev/null
#exec podman cp "$pubkey" ${hostname}:/home/box/.ssh/authorized_keys
#podman stop $hostname
