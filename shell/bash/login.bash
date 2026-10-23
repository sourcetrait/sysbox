#!/usr/bin/bash
set -euo pipefail
podman start box 1>/dev/null
exec podman exec -it --user box --workdir /home/box box bash
