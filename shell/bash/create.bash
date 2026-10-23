#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(realpath "$(dirname "$(readlink "${BASH_SOURCE[0]}")")/../..")"
source "$REPO_DIR/shell/bash/lib.bash"
cd $REPO_DIR

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

if [[ ! -f "$pubkey" || ! -s "$pubkey" ]]; then
    echo -e "error: pubkey not found: $pubkey"
    exit 1
fi

name="$hostname"
volume="${hostname}-home"

podman create --systemd=always --name $name --hostname $hostname --volume $volume:/home/box --volume /tmp "$(cfg image)"

podman start $hostname 1>/dev/null
exec podman cp "$pubkey" ${hostname}:/home/box/.ssh/authorized_keys
podman stop $hostname
