# endsys-coder-workspace

Coder workspace template for Kubernetes with `code-server`, Codex CLI, Claude Code, Gemini CLI, and Bitwarden Secrets Manager provisioning.

## What This Template Creates

This repo defines a complete Coder template:

- A Kubernetes-backed Coder workspace pod
- A persistent `/home/coder` volume for user state and auth caches
- A `coder_script` startup step that provisions secrets and starts `code-server`
- A Coder app named `VS Code` that points at the bundled `code-server` instance

## Included Tooling

- `code-server` for browser-based VS Code
- `codex` for OpenAI Codex CLI
- `claude` for Claude Code
- `gemini` for Gemini CLI
- `bws` for Bitwarden Secrets Manager
- `git`, `kubectl`, `helm`, `k9s`, `jq`, `yq`, `ripgrep`, `fd`, `fzf`, `tmux`, `zsh`, and Oh My Zsh

The AI CLIs are version-pinned in `Dockerfile` through build args so workspace image builds stay reproducible.

## Workspace Startup Flow

When a workspace starts, Coder runs `startup.sh` through `coder_script.workspace_setup`. That script:

1. Uses `BWS_ACCESS_TOKEN` to authenticate to Bitwarden Secrets Manager
2. Retrieves the SSH private key and kubeconfig secrets by ID
3. Validates the secret payloads before installing them
4. Starts `code-server` on port `13337`

Provisioned files:

| Secret | Destination | Validation |
|---|---|---|
| SSH private key | `~/.ssh/id_ed25519` | `ssh-keygen -y` must succeed |
| Kubeconfig | `~/.kube/config` | `kubectl config view` must succeed |

If Bitwarden returns empty or malformed data, workspace startup fails fast instead of leaving the workspace half-configured.

## Persistent State

The home PVC mounted at `/home/coder` persists user state across workspace restarts, including:

- shell history and dotfiles
- Git config and SSH config
- Claude Code auth state
- Gemini CLI auth state
- Codex CLI auth state, typically under `~/.codex/auth.json`

Treat Codex auth cache like a password. Do not commit it, paste it into tickets, or copy it into shared chat.

## Prerequisites

- Coder running on Kubernetes
- Access to a container registry for the workspace image
- [Bitwarden Secrets Manager](https://bitwarden.com/help/secrets-manager-overview/) with a machine account and access token
- Bitwarden secrets for the SSH private key and kubeconfig
- ChatGPT or OpenAI API access for Codex CLI
- Claude subscription or organization access for Claude Code
- Google account or organization access for Gemini CLI

## Bitwarden Setup

1. Enable **Secrets Manager** for the Bitwarden organization.
2. Create a project such as `coder-workspace`.
3. Add these secrets to that project:
   - `ssh-private-key`: the full private key contents
   - `kubeconfig`: the full kubeconfig YAML
4. Create a machine account and grant it read access to the project.
5. Generate the machine account access token.

## Build And Publish The Workspace Image

Build and push the image you want the Coder template to use:

```bash
docker build -t ghcr.io/shelmus/endsys-coder-workspace:v20260421 .
docker push ghcr.io/shelmus/endsys-coder-workspace:v20260421
```

The template pins the workspace image to `ghcr.io/shelmus/endsys-coder-workspace:v20260421`. If you need a different registry or newer tag for a specific workspace, set the optional `workspace_image_override` parameter instead.

## Push The Coder Template

```bash
coder templates push endsys-workspace --directory .
```

## Template Parameters

| Parameter | Description |
|---|---|
| `namespace` | Kubernetes namespace for the workspace pod |
| `workspace_image_override` | Optional full container image reference for the workspace pod |
| `home_volume_size` | PVC size in GiB |
| `cpu_limit` / `memory_limit` | Pod resource limits |
| `bws_access_token` | Bitwarden machine account access token |
| `bws_ssh_key_id` | Bitwarden secret ID for the SSH private key |
| `bws_kubeconfig_id` | Bitwarden secret ID for the kubeconfig |

## First Login In A Coder Workspace

After the workspace starts, open the Coder terminal and sign in to the tools you want to use:

```bash
# Codex CLI: browser login on a normal workspace
codex

# Codex CLI: preferred for headless or remote login flows
codex login --device-auth

# Claude Code
claude login

# Gemini CLI
gemini
```

Codex supports both ChatGPT sign-in and API-key sign-in. In a typical interactive Coder workspace, ChatGPT login is the default path. For automated or policy-controlled environments, use API-key auth instead.

## Template Maintenance

Terraform provider versions are pinned in `main.tf`, and `.terraform.lock.hcl` is intended to be committed. To refresh the lockfile after a provider upgrade:

```bash
terraform init -backend=false
```

This repo also includes CI for Coder template maintenance:

- `.github/workflows/validate.yml` validates Terraform, shell syntax, and the container build
- `.github/workflows/build.yml` publishes the workspace image on `main`

## Smoke Test Checklist

Run these after pushing a new image or template update:

```bash
codex --version
claude --version
gemini --version
bws --version
kubectl version --client
code-server --version
```

Then validate the Coder-specific behavior:

1. Push the template and create or update a workspace.
2. Confirm the `Workspace Setup` script completes successfully.
3. Confirm the `VS Code` app healthcheck passes.
4. Verify SSH and kubeconfig files are present in the workspace.
5. Restart the workspace and confirm CLI auth state still exists under `/home/coder`.
