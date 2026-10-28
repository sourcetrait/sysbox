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

name="$boxhost"
volume="${hostname}-home"
port=$(next_port 21501)

echo "[sysbox] creating container"
podman create --systemd=always --name $name --hostname $boxhost --volume $volume:/home --volume /mnt/cache -p $port:22 "$(cfg image)"

echo "[sysbox] starting container"
podman start $boxhost 1>/dev/null

echo "[sysbox] mounting cache"
podman exec -u root $boxhost mkdir -p /mnt/cache/{1000,1001}
podman exec -u root $boxhost mv /home/box/.sys/cache /mnt/cache/1000 && mnt /home/box/tmp /mnt/cache/1000
podman exec -u root $boxhost mv /home/super/.sys/cache /mnt/cache/1001 && mnt /home/super/tmp /mnt/cache/1001
podman exec -u root $boxhost chown 1000:1000 /mnt/cache/1000 /mnt/cache/1000/{cache,tmp} && chmod go-rwx /mnt/cache/1000 /mnt/cache/1000/{cache,tmp}
podman exec -u root $boxhost chown 1000:1000 /mnt/cache/1001 /mnt/cache/1001/{cache,tmp} && chmod go-rwx /mnt/cache/1001 /mnt/cache/1001/{cache,tmp}
podman exec -u root $boxhost ln /mnt/cache/1000/cache /home/box/.sys/cache && ln /mnt/cache/1000/tmp /home/box/tmp
podman exec -u root $boxhost ln /mnt/cache/1001/cache /home/super/.sys/cache && ln /mnt/cache/1001/tmp /home/super/tmp

echo "[sysbox] copying ssh keys"
podman cp "$box_pubkey" ${hostname}:/home/box/.ssh/authorized_keys
podman exec -u root $boxhost chmod 600 /home/box/.ssh/authorized_keys
podman exec -u root $boxhost chown box:box /home/box/.ssh/authorized_keys

podman cp "$super_pubkey" ${hostname}:/home/super/.ssh/authorized_keys
podman exec -u root $boxhost chmod 600 /home/super/.ssh/authorized_keys
podman exec -u root $boxhost chown super:super /home/super/.ssh/authorized_keys

echo "[sysbox] re-permission"
podman exec -u root $boxhost chown -R box:box /home/box && chmod -R go-rwx /home/box
podman exec -u root $boxhost chown -R super:super /mnt/cache/1001 && chmod -R go-rwx /home/super

echo "[sysbox] stopping container"
podman stop $boxhost

echo "[sysbox] configuring ssh hosts for container: $boxhost and super.$boxhost"
cat >$HOME/.ssh/config <<EOF

Host $boxhost
  Hostname localhost
  Port $port
  User box
  PreferredAuthentications publickey
  IdentityFile ~/.ssh/key/pod/$box/id_box

Host super.$boxhost
  Hostname localhost
  Port $port
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
