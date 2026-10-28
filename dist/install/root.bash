#!/usr/bin/env bash
set -euo pipefail
echo "[sysbox] install: root: begin"

echo "[sysbox] version-lock specific packages"
dnf versionlock add nushell

echo "[sysbox] disable optional services"
systemctl disable --now nginx.service

echo "[sysbox] copy filesystem"
tar -C /mnt/dist/fs --owner=0 --group=0 --mode=u=rwX,go=rX -cf - . \
| tar -C / --no-overwrite-dir -xf -

echo "[sysbox] create skels"
while IFS= read -r dir || [[ -n "$dir" ]]; do
    [[ -n "$dir" ]] || continue
    mkdir -p -- "/etc/sysbox/skel/uenv/$dir"
done < /mnt/dist/list/dir/uenv.list

while IFS= read -r dir || [[ -n "$dir" ]]; do
    [[ -n "$dir" ]] || continue
    mkdir -p -- "/etc/sysbox/skel/uenv-desk/$dir"
done < /mnt/dist/list/dir/uenv/desk.list


echo "[sysbox] permission for logins"
chmod 640 /etc/shadow

echo "[sysbox] create groups"
groupadd sshusr

echo "[sysbox] create user: box"
useradd -m -s /usr/bin/nu box
usermod -aG sshusr box
echo 'box:box' | chpasswd

echo "[sysbox] create user: super"
useradd -m -s /usr/bin/fish super
usermod -aG sshusr,wheel super
echo 'super:super' | chpasswd

echo "[sysbox] setup home: box"
cp -a /etc/sysbox/skel/uenv/. /home/box
cp -a /etc/sysbox/skel/uenv-desk/. /home/box
chmod -R go-rwx /home/box
chown -R box:box /home/box

echo "[sysbox] setup home: super"
cp -a /etc/sysbox/skel/uenv/. /home/super
cp -a /etc/sysbox/skel/uenv-desk/. /home/super
chmod -R go-rwx /home/super
chown -R super:super /home/super

echo "[sysbox] final cleanup and re-permission"
cd /root
chmod -R go-rwx /home/box
chown -R box:box /home/box
chmod -R go-rwx /home/super
chown -R super:super /home/super
rm -rf /tmp/* /tmp/.*
echo "[sysbox] install: root: done"
exit 0
