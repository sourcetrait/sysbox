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

ssh_config_exists() {
    local host
    host=${1:?hostname is required}

    awk -v name="$host" '
        tolower($1) == "host" {
            for (i = 2; i <= NF && $i !~ /^#/; i++)
                if ($i == name) found = 1
        }
        END { exit !found }
    ' ~/.ssh/config
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

# don't overwrite keys
if [[ -f "$box_key || -f "$super_key ]]; then
	echo -e "[sysbox] error: ssh keys already exist: $key_dir"
	exit 1
fi

# don't overwrite host configs
if ssh_config_exists "$hostname" || ssh_config_exists "super.$hostname"; then
	echo -e "[sysbox] error: ssh config hosts already exist: ~/.ssh/config"
fi

echo "[sysbox] creating ssh keys for users: box and super"
ssh-keygen -t ed25519 -C "box@${hostname}" -f "$box_key"
ssh-keygen -t ed25519 -C "super@${hostname}" -f "$super_key"
chmod -R go-rwx "$HOME/.ssh"

name="$hostname"
volume="${hostname}-home"
port=$(next_port 21501)

echo "[sysbox] creating container"
podman create --systemd=always --name $name --hostname $hostname --volume $volume:/home --volume /tmp -p $port:22 "$(cfg image)"

echo "[sysbox] starting container"
podman start $hostname 1>/dev/null

echo "[sysbox] copying ssh keys"
podman cp "$box_pubkey" ${hostname}:/home/box/.ssh/authorized_keys
podman exec -u root $hostname chmod 600 /home/box/.ssh/authorized_keys
podman exec -u root $hostname chown box:box /home/box/.ssh/authorized_keys

podman cp "$super_pubkey" ${hostname}:/home/super/.ssh/authorized_keys
podman exec -u root $hostname chmod 600 /home/super/.ssh/authorized_keys
podman exec -u root $hostname chown super:super /home/super/.ssh/authorized_keys

echo "[sysbox] stopping container"
podman stop $hostname

echo "[sysbox] configuring ssh hosts for container: $hostname and super.$hostname"
cat >$HOME<<EOF

Host $hostname
	Hostname localhost
	Port $port
	User box
	PreferredAuthentications publickey
	IdentityFile ~/.ssh/key/pod/$HOSTNAME/id_box

Host super.$hostname
	Hostname localhost
	Port $port
	User super
	PreferredAuthentications publickey
	IdentityFile ~/.ssh/key/pod/$HOSTNAME/id_super
EOF

echo "[sysbox] done"
