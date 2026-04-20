terraform {
  required_version = ">= 1.6.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.15.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.34"
    }
  }
}

provider "coder" {}

provider "kubernetes" {
  config_path = null # Uses Coder's service account
}

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# ---------------------------------------------------------------------------
# Template parameters
# ---------------------------------------------------------------------------

data "coder_parameter" "namespace" {
  name         = "namespace"
  display_name = "Kubernetes Namespace"
  description  = "Namespace to deploy the workspace pod"
  type         = "string"
  default      = "coder"
  mutable      = false
}

data "coder_parameter" "workspace_image" {
  name         = "workspace_image"
  display_name = "Workspace Image"
  description  = "Container image for the Coder workspace pod"
  type         = "string"
  default      = "ghcr.io/shelmus/endsys-coder-workspace:latest"
  mutable      = true
}

data "coder_parameter" "home_volume_size" {
  name         = "home_volume_size"
  display_name = "Home Volume Size (GiB)"
  description  = "Size of the persistent volume for /home/coder"
  type         = "number"
  default      = "20"
  mutable      = true

  option {
    name  = "10 GiB"
    value = "10"
  }
  option {
    name  = "20 GiB"
    value = "20"
  }
  option {
    name  = "50 GiB"
    value = "50"
  }

  validation {
    monotonic = "increasing"
  }
}

data "coder_parameter" "cpu_limit" {
  name         = "cpu_limit"
  display_name = "CPU Limit (cores)"
  description  = "Maximum CPU cores for the workspace"
  type         = "number"
  default      = "4"
  mutable      = true

  option {
    name  = "2 cores"
    value = "2"
  }
  option {
    name  = "4 cores"
    value = "4"
  }
  option {
    name  = "8 cores"
    value = "8"
  }
}

data "coder_parameter" "memory_limit" {
  name         = "memory_limit"
  display_name = "Memory Limit (GiB)"
  description  = "Maximum memory for the workspace"
  type         = "number"
  default      = "8"
  mutable      = true

  option {
    name  = "4 GiB"
    value = "4"
  }
  option {
    name  = "8 GiB"
    value = "8"
  }
  option {
    name  = "16 GiB"
    value = "16"
  }
}

data "coder_parameter" "bws_access_token" {
  name         = "bws_access_token"
  display_name = "Bitwarden Secrets Manager Access Token"
  description  = "Machine account access token for Bitwarden Secrets Manager"
  type         = "string"
  mutable      = true
}

data "coder_parameter" "bws_ssh_key_id" {
  name         = "bws_ssh_key_id"
  display_name = "BWS SSH Key Secret ID"
  description  = "UUID of the Bitwarden Secrets Manager secret containing the SSH private key"
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "bws_kubeconfig_id" {
  name         = "bws_kubeconfig_id"
  display_name = "BWS Kubeconfig Secret ID"
  description  = "UUID of the Bitwarden Secrets Manager secret containing the kubeconfig"
  type         = "string"
  default      = ""
  mutable      = true
}


# ---------------------------------------------------------------------------
# Coder agent
# ---------------------------------------------------------------------------

resource "coder_agent" "dev" {
  os   = "linux"
  arch = "amd64"
  dir  = "/home/coder"

  display_apps {
    web_terminal = true
    vscode       = true
  }

  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage"
    key          = "mem"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Disk Usage"
    key          = "disk"
    script       = "coder stat disk --path /home/coder"
    interval     = 60
    timeout      = 1
  }

  resources_monitoring {
    memory {
      enabled   = true
      threshold = 90
    }
    volume {
      path      = "/home/coder"
      enabled   = true
      threshold = 85
    }
  }
}

# Pass environment variables to the agent
resource "coder_env" "git_author_name" {
  agent_id = coder_agent.dev.id
  name     = "GIT_AUTHOR_NAME"
  value    = data.coder_workspace_owner.me.full_name
}

resource "coder_env" "git_author_email" {
  agent_id = coder_agent.dev.id
  name     = "GIT_AUTHOR_EMAIL"
  value    = data.coder_workspace_owner.me.email
}

resource "coder_env" "git_committer_name" {
  agent_id = coder_agent.dev.id
  name     = "GIT_COMMITTER_NAME"
  value    = data.coder_workspace_owner.me.full_name
}

resource "coder_env" "git_committer_email" {
  agent_id = coder_agent.dev.id
  name     = "GIT_COMMITTER_EMAIL"
  value    = data.coder_workspace_owner.me.email
}

resource "coder_env" "bws_access_token" {
  agent_id = coder_agent.dev.id
  name     = "BWS_ACCESS_TOKEN"
  value    = data.coder_parameter.bws_access_token.value
}

resource "coder_env" "bws_ssh_key_id" {
  agent_id = coder_agent.dev.id
  name     = "BWS_SSH_KEY_ID"
  value    = data.coder_parameter.bws_ssh_key_id.value
}

resource "coder_env" "bws_kubeconfig_id" {
  agent_id = coder_agent.dev.id
  name     = "BWS_KUBECONFIG_ID"
  value    = data.coder_parameter.bws_kubeconfig_id.value
}


# ---------------------------------------------------------------------------
# Startup script
# ---------------------------------------------------------------------------

resource "coder_script" "workspace_setup" {
  agent_id           = coder_agent.dev.id
  display_name       = "Workspace Setup"
  run_on_start       = true
  start_blocks_login = true
  timeout            = 300
  script             = file("startup.sh")
}

# ---------------------------------------------------------------------------
# code-server app
# ---------------------------------------------------------------------------

resource "coder_app" "code_server" {
  agent_id     = coder_agent.dev.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:13337?folder=/home/coder"
  icon         = "/icon/code.svg"
  share        = "owner"
  subdomain    = false

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

# ---------------------------------------------------------------------------
# Persistent volume claim
# ---------------------------------------------------------------------------

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}-home"
    namespace = data.coder_parameter.namespace.value
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.home_volume_size.value}Gi"
      }
    }
  }

  lifecycle {
    ignore_changes = [spec[0].resources]
  }
}

# ---------------------------------------------------------------------------
# Workspace pod
# ---------------------------------------------------------------------------

resource "kubernetes_pod" "workspace" {
  count = data.coder_workspace.me.start_count

  metadata {
    name      = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
    namespace = data.coder_parameter.namespace.value

    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = lower(data.coder_workspace.me.name)
    }
  }

  spec {
    automount_service_account_token = false

    security_context {
      run_as_user = 1000
      fs_group    = 1000
    }

    container {
      name  = "dev"
      image = data.coder_parameter.workspace_image.value

      command = ["sh", "-c", coder_agent.dev.init_script]

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.dev.token
      }

      resources {
        requests = {
          cpu    = "500m"
          memory = "1Gi"
        }
        limits = {
          cpu    = "${data.coder_parameter.cpu_limit.value}"
          memory = "${data.coder_parameter.memory_limit.value}Gi"
        }
      }

      volume_mount {
        name       = "home"
        mount_path = "/home/coder"
      }
    }

    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata[0].name
      }
    }
  }
}
