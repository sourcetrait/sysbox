#!/usr/bin/env bash
set -euo pipefail

# copy system dist
cp /mnt/dist/repo/*.repo /etc/yum.repos.d
cp /mnt/dist/etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config.d

# install packages
mapfile -t packages < /mnt/dist/packages.list
mapfile -t coprs < /mnt/dist/coprs.list

for copr in "${coprs[@]"; do
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
cp -a --update=none /etc/skel/. /home/box

# scaffold home: box
cd /home/box && mkdir -p .config .sys .ssh ai bak data proj repo doc down tmp mix tpl sort
cd /home/box/.sys && mkdir -p of srv/git local adhoc mnt cache data
cd /home/box/.sys/local && mkdir -p bin etc lib libexec man src doc opt
cd /home/box/.sys/adhoc && mkdir -p bin etc lib libexec man src doc opt

mkdir -p /home/box/.config/bash
cp /mnt/dist/sysbox.bashrc /home/box/.config/bash/sysbox.bashrc
echo 'source $HOME/.config/bash/sysbox.bashrc' >> /home/box/.bashrc

touch /home/box/.ssh/config
touch /home/box/.ssh/authorized_keys

chmod -R go-rwx /home/box
chown -R box:box /home/box

# cleanup
cd /root
rm -rf /tmp/* /tmp/.*
