#!/usr/bin/env bash
# Copy the CPU scripts to the agent host and pin that host at 100% CPU
# under the process name cpu-load-other. The spike starts immediately.
# Keep this terminal open for the run (3 minutes by default). Ctrl-C stops the load.
#
# Requires AGENT_HOST in .env. Optional: AGENT_USER (default ubuntu),
# AGENT_SSH_PORT (default 22), AGENT_SSH_KEY.
set -euo pipefail
source "$(dirname "$0")/_remote.sh"
upload_cpu_load
run_cpu_load --comm cpu-load-other "$@"
