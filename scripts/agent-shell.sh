#!/usr/bin/env bash
# Open an interactive shell on the Elastic Agent host.
# Requires AGENT_HOST in .env. Optional: AGENT_USER, AGENT_SSH_PORT, AGENT_SSH_KEY.
set -euo pipefail
source "$(dirname "$0")/_remote.sh"
exec ssh -t "${SSH_BASE[@]}" "$agent_target"
