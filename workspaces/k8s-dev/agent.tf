resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"
  dir  = local.workspace_folder

  display_apps {
    vscode                 = false
    vscode_insiders        = false
    web_terminal           = true
    ssh_helper             = true
    port_forwarding_helper = true
  }

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "2_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }
}

resource "coder_metadata" "workspace" {
  count       = data.coder_workspace.me.start_count
  resource_id = coder_agent.main.id
  icon        = "/icon/k8s.svg"

  item {
    key   = "Kubernetes access"
    value = "User-supplied ~/.kube/config"
  }

  item {
    key   = "Workspace size"
    value = data.coder_parameter.customize_specs.value ? "Custom" : local.workspace_size.display_name
  }

  item {
    key   = "CPU"
    value = "${local.cpu_limit} cores requested / limited"
  }

  item {
    key   = "Memory"
    value = "${local.memory_limit} requested / limited"
  }

  item {
    key   = "Temporary storage"
    value = "${local.ephemeral_storage_request} requested / ${local.ephemeral_storage_limit} limit; ${local.tmp_size_limit} `/tmp` limit"
  }

  item {
    key   = "Repository"
    value = local.repository == "" ? "None" : local.repository
  }

  item {
    key   = "Source revision"
    value = local.git_branch == "" ? "None" : local.git_branch
  }
}

module "coder_login" {
  source = "/opt/coder-modules/coder-login"

  agent_id = coder_agent.main.id
}

module "git_config" {
  source = "/opt/coder-modules/git-config"

  agent_id              = coder_agent.main.id
  allow_username_change = false
  allow_email_change    = false
}

module "git_clone" {
  count  = local.repository == "" ? 0 : 1
  source = "/opt/coder-modules/git-clone"

  agent_id    = coder_agent.main.id
  url         = local.repository_url
  branch_name = local.git_branch
  base_dir    = "/home/coder"
  folder_name = local.repository_name
  extra_args  = ["--single-branch"]
}

module "code_server" {
  source = "/opt/coder-modules/code-server"

  agent_id       = coder_agent.main.id
  folder         = local.workspace_folder
  offline        = true
  install_prefix = "/opt/code-server"
  extensions_dir = "/home/coder/.local/share/code-server/extensions"
  settings = {
    "extensions.autoCheckUpdates"              = false
    "extensions.autoUpdate"                    = false
    "telemetry.telemetryLevel"                 = "off"
    "terminal.integrated.defaultProfile.linux" = "zsh"
    "terminal.integrated.cwd"                  = local.workspace_folder
    "terminal.integrated.profiles.linux" = {
      zsh = {
        path = "/usr/bin/zsh"
      }
    }
  }
  additional_args = join(" ", [
    "--disable-telemetry",
    "--disable-update-check",
  ])
}
