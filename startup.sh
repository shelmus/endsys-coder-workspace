#!/usr/bin/env bash
set -euo pipefail

log() { echo "==> [$(date '+%H:%M:%S')] $*"; }
warn() { echo "==> [$(date '+%H:%M:%S')] WARNING: $*" >&2; }
fail() { echo "==> [$(date '+%H:%M:%S')] ERROR: $*" >&2; exit 1; }

# Helper: fetch a secret value from Bitwarden Secrets Manager by ID
bws_get() {
  bws secret get "$1" --output json | jq -r '.value'
}

# ---------------------------------------------------------------------------
# Phase 1: Validate Bitwarden Secrets Manager access
# ---------------------------------------------------------------------------
if [ -z "${BWS_ACCESS_TOKEN:-}" ]; then
  fail "BWS_ACCESS_TOKEN must be set"
fi

export BWS_ACCESS_TOKEN
log "Bitwarden Secrets Manager authenticated"

# ---------------------------------------------------------------------------
# Phase 2: SSH keys
# ---------------------------------------------------------------------------
if [ -n "${BWS_SSH_KEY_ID:-}" ]; then
  log "Provisioning SSH keys..."
  mkdir -p ~/.ssh && chmod 700 ~/.ssh

  bws_get "$BWS_SSH_KEY_ID" > ~/.ssh/id_ed25519
  chmod 600 ~/.ssh/id_ed25519

  # Generate public key from private key
  ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub 2>/dev/null || true
  chmod 644 ~/.ssh/id_ed25519.pub

  # SSH config for GitHub
  if [ ! -f ~/.ssh/config ]; then
    cat > ~/.ssh/config <<'SSHEOF'
Host github.com
  IdentityFile ~/.ssh/id_ed25519
  StrictHostKeyChecking accept-new
SSHEOF
    chmod 600 ~/.ssh/config
  fi

  log "SSH keys installed"
else
  warn "BWS_SSH_KEY_ID not set, skipping SSH key provisioning"
fi

# ---------------------------------------------------------------------------
# Phase 3: Kubernetes configuration
# ---------------------------------------------------------------------------
if [ -n "${BWS_KUBECONFIG_ID:-}" ]; then
  log "Provisioning kubeconfig..."
  mkdir -p ~/.kube && chmod 700 ~/.kube

  bws_get "$BWS_KUBECONFIG_ID" > ~/.kube/config
  chmod 600 ~/.kube/config

  log "Kubeconfig installed"
else
  warn "BWS_KUBECONFIG_ID not set, skipping kubeconfig provisioning"
fi

# ---------------------------------------------------------------------------
# Phase 4: Cleanup
# ---------------------------------------------------------------------------
unset BWS_ACCESS_TOKEN

# ---------------------------------------------------------------------------
# Phase 6: Start code-server
# ---------------------------------------------------------------------------
log "Starting code-server..."
code-server --auth none --port 13337 --host 0.0.0.0 &

log "Workspace setup complete"
