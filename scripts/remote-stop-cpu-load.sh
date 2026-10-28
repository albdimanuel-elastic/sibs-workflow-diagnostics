#!/usr/bin/env bash
# Stop a remote CPU load started by remote-high-cpu-not-edr.sh or remote-high-cpu-edr.sh.
# Requires AGENT_HOST in .env.
set -euo pipefail
source "$(dirname "$0")/_remote.sh"
stop_remote_cpu_load
