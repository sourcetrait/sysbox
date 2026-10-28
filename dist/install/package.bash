#!/usr/bin/env bash
set -euo pipefail
echo "[sysbox] install: package: begin"

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
