# Shared SSH settings for the Elastic Agent host.
# Sourced by the remote-*.sh scripts. Expects to be sourced, not executed.
if [[ -n "${SIBS_REMOTE_LOADED:-}" ]]; then
  return 0
fi
SIBS_REMOTE_LOADED=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

: "${AGENT_HOST:?Set AGENT_HOST in .env to the agent machine IP}"
AGENT_USER="${AGENT_USER:-ubuntu}"
AGENT_SSH_PORT="${AGENT_SSH_PORT:-22}"
REMOTE_DIR="${AGENT_REMOTE_DIR:-/tmp/sibs-cpu-load}"

SSH_BASE=(
  -p "$AGENT_SSH_PORT"
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=accept-new
)
SCP_BASE=(
  -P "$AGENT_SSH_PORT"
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=accept-new
)
if [[ -n "${AGENT_SSH_KEY:-}" ]]; then
  SSH_BASE+=(-i "$AGENT_SSH_KEY" -o IdentitiesOnly=yes)
  SCP_BASE+=(-i "$AGENT_SSH_KEY" -o IdentitiesOnly=yes)
fi

agent_target="${AGENT_USER}@${AGENT_HOST}"

upload_cpu_load() {
  ssh "${SSH_BASE[@]}" "$agent_target" "mkdir -p $(printf '%q' "$REMOTE_DIR")"
  scp "${SCP_BASE[@]}" \
    "$ROOT/scripts/cpu_load.py" \
    "${agent_target}:${REMOTE_DIR}/cpu_load.py"
}

run_cpu_load() {
  local extra=""
  if (($#)); then
    extra="$(printf ' %q' "$@")"
  fi
  # -t so Ctrl-C on this Mac reaches the load process on the agent host.
  ssh -t "${SSH_BASE[@]}" "$agent_target" \
    "exec python3 $(printf '%q' "$REMOTE_DIR/cpu_load.py")${extra}"
}

stop_remote_cpu_load() {
  ssh "${SSH_BASE[@]}" "$agent_target" 'bash -s' << 'EOF'
set -euo pipefail
pidfile=/tmp/sibs-cpu-load.pid
if [[ ! -f "$pidfile" ]]; then
  echo "No CPU load pidfile at $pidfile"
  exit 0
fi
pgid="$(tr -d '[:space:]' < "$pidfile")"
kill -TERM -- "-${pgid}" 2>/dev/null || true
rm -f "$pidfile"
echo "Stopped CPU load process group ${pgid}"
EOF
}
