#!/usr/bin/env bash
# Remote shell on the Elastic Agent host.
#
#   ./remote-shell.sh            open a shell and run OS commands yourself
#   ./remote-shell.sh top        show which processes are using CPU right now
#   ./remote-shell.sh <command>  run that command on the host
#
# Requires AGENT_HOST in .env. Optional: AGENT_USER, AGENT_SSH_PORT, AGENT_SSH_KEY.
set -euo pipefail
source "$(dirname "$0")/_remote.sh"

if (($# == 0)); then
  echo "Shell on ${agent_target}. Leave it with exit."
  echo "CPU snapshot from here: $(basename "$0") top"
  exec ssh -t "${SSH_BASE[@]}" "$agent_target"
fi

if [[ "$1" == "top" ]]; then
  ssh "${SSH_BASE[@]}" "$agent_target" 'bash -s' << 'EOF'
set -euo pipefail
echo "Host: $(hostname)   cores: $(nproc)"
echo
echo "Host CPU over 1 second:"
read -r _ u1 n1 s1 i1 rest < /proc/stat
sleep 1
read -r _ u2 n2 s2 i2 rest < /proc/stat
awk -v u1="$u1" -v n1="$n1" -v s1="$s1" -v i1="$i1" \
    -v u2="$u2" -v n2="$n2" -v s2="$s2" -v i2="$i2" 'BEGIN {
      busy = (u2-u1) + (n2-n1) + (s2-s1)
      total = busy + (i2-i1)
      if (total < 1) total = 1
      printf "  %.1f%%\n", 100 * busy / total
    }'
echo
echo "Processes using CPU now (top, second sample):"
top -b -n 2 -d 1 -w 180 | awk 'BEGIN { snap = 0 } /^top -/ { snap++; next } snap == 2 { lines[++n] = $0 } END { limit = n < 18 ? n : 18; for (i = 1; i <= limit; i++) print lines[i] }'
echo
echo "Process comm names, highest lifetime %CPU first:"
ps -eo pid,pcpu,comm --sort=-pcpu | awk 'NR <= 16'
EOF
  exit 0
fi

ssh -t "${SSH_BASE[@]}" "$agent_target" "$@"
