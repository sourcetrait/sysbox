#!/usr/bin/env bash
set -euo pipefail
REPO_DIR=$(cd -L -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd -L)
source "$REPO_DIR/shell/bash/lib.bash"
cd $REPO_DIR

podman build -t localhost/sysbox "$REPO_DIR/contain"
