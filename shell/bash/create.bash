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

if [[ -z "$boxhost" ]]; then
    usage
fi

if [[ ! -f "$HOME/.ssh/config" ]]; then
    mkdir -p "$HOME/.ssh"
    touch "$HOME/.ssh/config"
    chmod -R go-rwx "$HOME/.ssh"
fi

key_dir="$HOME/.ssh/key/pod/$boxhost"
box_key="$key_dir/id_box"
box_pubkey="$key_dir/id_box.pub"
super_key="$key_dir/id_super"
super_pubkey="$key_dir/id_super.pub"

# don't overwrite keys
if [[ -f "$box_key" || -f "$super_key" ]]; then
	echo -e "[sysbox] error: ssh keys already exist: $key_dir"
	exit 1
fi

# don't overwrite host configs
if ssh_config_exists "$boxhost" || ssh_config_exists "super.$boxhost"; then
	echo -e "[sysbox] error: ssh config hosts already exist: ~/.ssh/config"
fi

echo "[sysbox] creating ssh keys for users: box and super"
mkdir -p "$key_dir"
ssh-keygen -t ed25519 -C "box@${hostname}" -f "$box_key"
ssh-keygen -t ed25519 -C "super@${hostname}" -f "$super_key"
chmod -R go-rwx "$HOME/.ssh"

volume="${hostname}-home"
ssh_port=$(next_port 21501)

echo "[sysbox] creating container"
podman create --name $boxhost --hostname $boxhost \
 --systemd=always \
 -p $ssh_port:22 \
 --volume $volume:/home \
 --volume /home/box/.sys/cache \
 --volume /home/box/tmp \
 --volume /home/super/tmp \
 --volume /home/super/.sys/cache \
 "$(cfg image)"

echo "[sysbox] starting container"
podman start $boxhost 1>/dev/null

echo "[sysbox] copying ssh keys"
podman cp "$box_pubkey" ${hostname}:/home/box/.ssh/authorized_keys
podman exec -u root $boxhost chmod 600 /home/box/.ssh/authorized_keys
podman exec -u root $boxhost chown box:box /home/box/.ssh/authorized_keys

podman cp "$super_pubkey" ${hostname}:/home/super/.ssh/authorized_keys
podman exec -u root $boxhost chmod 600 /home/super/.ssh/authorized_keys
podman exec -u root $boxhost chown super:super /home/super/.ssh/authorized_keys

echo "[sysbox] stopping container"
podman stop $boxhost

echo "[sysbox] configuring ssh hosts for container: $boxhost and super.$boxhost"
cat >$HOME/.ssh/config <<EOF
Host $boxhost
  Hostname localhost
  Port $ssh_port
  User box
  PreferredAuthentications publickey
  IdentityFile ~/.ssh/key/pod/$boxhost/id_box
Host super.$boxhost
  Hostname localhost
  Port $ssh_port
  User super
  PreferredAuthentications publickey
  IdentityFile ~/.ssh/key/pod/$boxhost/id_super
EOF

echo "[sysbox] instructions:"
echo "[sysbox] start: `podman start $boxhost`"
echo "[sysbox] stop:  `podman stop $boxhost`"
echo "[sysbox] ssh:   `ssh $boxhost`"
echo "[sysbox] admin: `ssh super.$boxhost`"
echo "[sysbox] done"
