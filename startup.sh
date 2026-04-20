#!/usr/bin/env bash
set -euo pipefail

log() { echo "==> [$(date '+%H:%M:%S')] $*"; }
warn() { echo "==> [$(date '+%H:%M:%S')] WARNING: $*" >&2; }
fail() { echo "==> [$(date '+%H:%M:%S')] ERROR: $*" >&2; exit 1; }

# Helper: write a non-empty Bitwarden secret to a file
bws_write_secret() {
  local secret_id="$1"
  local destination="$2"
  local secret_name="$3"

  if ! bws secret get "$secret_id" --output json \
    | jq -er '.value | select(type == "string" and length > 0)' > "$destination"; then
    fail "Bitwarden secret for ${secret_name} is missing or empty"
  fi
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

  tmp_private_key="$(mktemp)"
  tmp_public_key="$(mktemp)"

  bws_write_secret "$BWS_SSH_KEY_ID" "$tmp_private_key" "SSH private key"
  chmod 600 "$tmp_private_key"

  if ! ssh-keygen -y -f "$tmp_private_key" > "$tmp_public_key" 2>/dev/null; then
    rm -f "$tmp_private_key" "$tmp_public_key"
    fail "Bitwarden SSH secret is not a valid private key"
  fi

  chmod 644 "$tmp_public_key"
  mv "$tmp_private_key" ~/.ssh/id_ed25519
  mv "$tmp_public_key" ~/.ssh/id_ed25519.pub

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

  tmp_kubeconfig="$(mktemp)"

  bws_write_secret "$BWS_KUBECONFIG_ID" "$tmp_kubeconfig" "kubeconfig"
  chmod 600 "$tmp_kubeconfig"

  if ! kubectl config view --kubeconfig "$tmp_kubeconfig" >/dev/null 2>&1; then
    rm -f "$tmp_kubeconfig"
    fail "Bitwarden kubeconfig secret is not valid kubeconfig YAML"
  fi

  mv "$tmp_kubeconfig" ~/.kube/config

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
code-server --auth none --port 13337 --host 0.0.0.0 > /tmp/code-server.log 2>&1 &

log "Workspace setup complete"
