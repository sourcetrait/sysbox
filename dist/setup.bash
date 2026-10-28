#!/usr/bin/env bash
set -euo pipefail

# copy system dist
cp -a /mnt/dist/fhs/. /

# install packages
mapfile -t packages < /mnt/dist/list/package.list
mapfile -t coprs < /mnt/dist/list/copr.list

for copr in "${coprs[@]}"; do
    dnf -y copr enable "$copr"
done

dnf -y install "${packages[@]}"
dnf -y upgrade
dnf clean all

# version locking
dnf versionlock add nushell

# disable optional services
systemctl disable --now nginx.service

# required for ssh to work with logins
chmod 640 /etc/shadow

# create groups
groupadd sshusr

# create user: box
useradd -m -s /usr/bin/nu box
usermod -aG sshusr box
echo 'box:box' | chpasswd

while IFS= read -r dir || [[ -n "$dir" ]]; do
    [[ -n "$dir" ]] || continue
    mkdir -p -- "/etc/sysbox/skel/uenv/$dir"
done < /mnt/dist/list/dir/uenv.list

while IFS= read -r dir || [[ -n "$dir" ]]; do
    [[ -n "$dir" ]] || continue
    mkdir -p -- "/etc/sysbox/skel/uenv-desk/$dir"
done < /mnt/dist/list/dir/uenv/desk.list

chmod -R go-rwx /home/box
chown -R box:box /home/box

# cleanup
cd /root
rm -rf /tmp/* /tmp/.*
