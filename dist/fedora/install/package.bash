#!/usr/bin/env bash
set -euo pipefail
echo "[sysbox] install: package: begin"

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

echo "[sysbox] install coprs"
mapfile -t coprs < /mnt/dist/list/copr.list

for copr in "${coprs[@]}"; do
    dnf -y copr enable "$copr"
done

echo "[sysbox] install packages"
mapfile -t packages < /mnt/dist/list/package.list
dnf -y install "${packages[@]}"

echo "[sysbox] update"
dnf -y upgrade

echo "[sysbox] clean"
dnf clean all

echo "[sysbox] install: package: done"
exit 0
