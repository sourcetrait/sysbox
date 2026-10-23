#!/usr/bin/bash
cp /mnt/dist/repo/*.repo /etc/yum.repos.d
dnf -y install systemd python3 nushell helix
dnf clean all

adduser box
cp -a --update=none /etc/skel/. /home/box

cd /home/box && mkdir -p .config .sys .ssh ai bak data proj repo doc down tmp mix tpl sort
cd /home/box/.sys && mkdir -p of srv/git local adhoc mnt cache config
cd /home/box/.sys/local && mkdir -p bin etc lib libexec man src doc opt
cd /home/box/.sys/adhoc && mkdir -p bin etc lib libexec man src doc opt

cp /mnt/dist/box.bashrc /home/box/.sys/local/etc/box.bashrc
echo 'source $HOME/.sys/local/etc/box.bashrc' >> /home/box/.bashrc
chmod -R 700 /home/box
chown -R box:box /home/box

cd /root
rm -rf /tmp/* /tmp/.*
