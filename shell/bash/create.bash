#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(realpath "$(dirname "$(readlink "${BASH_SOURCE[0]}")")/../..")"
source "$REPO_DIR/shell/bash/lib.bash"
cd $REPO_DIR

hostname="${1:-}"

usage() {
    echo -e "creates a sysbox podman container"
    echo -e "usage: create.bash <hostname>"
    exit 1
}

if [[ -z "$hostname" ]]; then
    usage
fi

key_dir="$HOME/.ssh/key/pod/$HOSTNAME"
box_key="$key_dir/id_box"
box_pubkey="$key_dir/id_box"
super_key="$key_dir/id_super.pub"
super_pubkey="$key_dir/id_super.pub"
mkdir -p "$key_dir"
ssh-keygen -t ed25519 -C "box@${hostname}" -f "$box_key"
ssh-keygen -t ed25519 -C "super@${hostname}" -f "$super_key"
chmod -R go-rwx "$HOME/.ssh"

name="$hostname"
volume="${hostname}-home"
port=$(next_port 21501)

podman create --systemd=always --name $name --hostname $hostname --volume $volume:/home --volume /tmp -p $port:22 "$(cfg image)"

podman start $hostname 1>/dev/null

podman cp "$box_pubkey" ${hostname}:/home/box/.ssh/authorized_keys
podman exec -u root $hostname chmod 600 /home/box/.ssh/authorized_keys
podman exec -u root $hostname chown box:box /home/box/.ssh/authorized_keys

podman cp "$super_pubkey" ${hostname}:/home/super/.ssh/authorized_keys
podman exec -u root $hostname chmod 600 /home/super/.ssh/authorized_keys
podman exec -u root $hostname chown super:super /home/super/.ssh/authorized_keys

podman stop $hostname

