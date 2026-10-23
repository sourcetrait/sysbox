#!/usr/bin/bash
cp /mnt/dist/repo/*.repo /etc/yum.repos.d
dnf -y copr enable lihaohong/yazi
dnf -y install systemd python3 nushell helix openssh-server dnf-plugins-core yazi nodejs24 npm ripgrep python3 fd-find jq git-lfs clang cmake openssl-devel
dnf -y upgrade
dnf clean all

# required for ssh to work with logins
chmod 640 /etc/shadow

groupadd sshusr
cp /mnt/dist/etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config.d

useradd -m -s /usr/bin/nu box
usermod -aG sshusr box
echo 'box:box' | chpasswd
cp -a --update=none /etc/skel/. /home/box

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

cd /root
rm -rf /tmp/* /tmp/.*
