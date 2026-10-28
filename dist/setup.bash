#!/usr/bin/env bash
set -euo pipefail

# copy system dist
tar -C /mnt/dist/fs --owner=0 --group=0 --mode=u=rwX,go=rX -cf - . \
| tar -C / --no-overwrite-dir -xf -

# create skels
while IFS= read -r dir || [[ -n "$dir" ]]; do
    [[ -n "$dir" ]] || continue
    mkdir -p -- "/etc/sysbox/skel/uenv/$dir"
done < /mnt/dist/list/dir/uenv.list

while IFS= read -r dir || [[ -n "$dir" ]]; do
    [[ -n "$dir" ]] || continue
    mkdir -p -- "/etc/sysbox/skel/uenv-desk/$dir"
done < /mnt/dist/list/dir/uenv/desk.list

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
# create user: super
useradd -m -s /usr/bin/fish super
usermod -aG sshusr,wheel super
echo 'super:super' | chpasswd

# setup home: box
cp -a /etc/sysbox/skel/uenv/. /home/box
cp -a /etc/sysbox/skel/uenv-desk/. /home/box
chmod -R go-rwx /home/box
chown -R box:box /home/box
# setup home: super
cp -a /etc/sysbox/skel/uenv/. /home/super
cp -a /etc/sysbox/skel/uenv-desk/. /home/super
chmod -R go-rwx /home/super
chown -R super:super /home/super

# cleanup
cd /root
rm -rf /tmp/* /tmp/.*
