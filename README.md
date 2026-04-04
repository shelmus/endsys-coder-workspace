# endsys-coder-workspace

Coder workspace template for Kubernetes with code-server, Claude Code, Gemini CLI, and Bitwarden Secrets Manager for secret provisioning.

## Tools Included

- **code-server** — VS Code in the browser
- **Claude Code** — Anthropic CLI agent (authenticate via `claude login`)
- **Gemini CLI** — Google AI CLI agent (authenticate via `gemini` first-run)
- **bws** — Bitwarden Secrets Manager CLI
- **git**, **kubectl**, **helm**, **k9s**, **jq**, **yq**, **ripgrep**, **fd**, **fzf**, **tmux**, **zsh** + Oh My Zsh

## How It Works

On workspace start, `startup.sh` uses a Bitwarden Secrets Manager machine account access token to fetch:

| Secret | BWS Secret Value | Destination |
|---|---|---|
| SSH private key | Full private key text | `~/.ssh/id_ed25519` |
| Kubeconfig | Full kubeconfig YAML | `~/.kube/config` |

Claude Code and Gemini CLI authenticate via browser OAuth on first use. Tokens persist on the home volume PVC across workspace restarts.

## Prerequisites

- Coder instance running on Kubernetes
- Container image pushed to a registry (e.g., `ghcr.io/shelmus/endsys-coder-workspace:latest`)
- [Bitwarden Secrets Manager](https://bitwarden.com/help/secrets-manager-overview/) with a machine account and access token
- Secrets created in BWS for SSH key and kubeconfig
- Claude Max subscription (for Claude Code)
- Google AI Pro/Ultra subscription (for Gemini CLI)

## Bitwarden Secrets Manager Setup

1. In Bitwarden, enable **Secrets Manager** for your organization
2. Create a **project** (e.g., `coder-workspace`)
3. Create **secrets** in the project:
   - `ssh-private-key` — paste your full SSH private key as the value
   - `kubeconfig` — paste your full kubeconfig YAML as the value
4. Create a **machine account**, grant it read access to the project
5. Generate an **access token** for the machine account

## First Login

After creating the workspace, open a terminal and run:

```bash
# Claude Code — opens browser OAuth flow
claude login

# Gemini CLI — opens browser OAuth flow on first run
gemini
```

These only need to be done once — tokens are cached on the persistent home volume.

## Build & Push Image

```bash
docker build -t ghcr.io/shelmus/endsys-coder-workspace:latest .
docker push ghcr.io/shelmus/endsys-coder-workspace:latest
```

## Deploy Template

```bash
coder templates push endsys-workspace --directory .
```

## Template Parameters

When creating a workspace, you'll be prompted for:

| Parameter | Description |
|---|---|
| `namespace` | Kubernetes namespace (default: `coder`) |
| `home_volume_size` | PVC size in GiB (10/20/50) |
| `cpu_limit` / `memory_limit` | Resource limits |
| `bws_access_token` | Bitwarden Secrets Manager machine account access token |
| `bws_ssh_key_id` | UUID of the BWS secret containing the SSH private key |
| `bws_kubeconfig_id` | UUID of the BWS secret containing the kubeconfig |
