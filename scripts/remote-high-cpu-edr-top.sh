#!/usr/bin/env bash
# Copy the CPU scripts to the agent host and run the mixed load:
# host above 90%, elastic-endpoin under 70% of one core and still the busiest process.
# The spike starts immediately. Keep this terminal open (3 minutes by default).
# If rule defend-host-cpu-90 is enabled, the alert requests a real Fleet diagnostics bundle.
#
# Requires AGENT_HOST in .env. Optional: AGENT_USER, AGENT_SSH_PORT, AGENT_SSH_KEY.
set -euo pipefail
source "$(dirname "$0")/_remote.sh"
upload_cpu_load
run_cpu_load --mix "$@"
