locals {
  default_home_disk_size = 20

  workspace_sizes = {
    small = {
      display_name = "Small"
      cpu          = 1
      memory       = 2
    }
    standard = {
      display_name = "Standard"
      cpu          = 2
      memory       = 4
    }
    large = {
      display_name = "Large"
      cpu          = 4
      memory       = 8
    }
  }

  repository        = trim(data.coder_parameter.repository.value, "/")
  repository_parts  = local.repository == "" ? [] : split("/", local.repository)
  repository_name   = local.repository == "" ? "" : local.repository_parts[length(local.repository_parts) - 1]
  repository_url    = local.repository == "" ? "" : "${var.git_base_url}/${local.repository}.git"
  workspace_folder  = local.repository_name == "" ? "/home/coder" : "/home/coder/${local.repository_name}"
  git_branch        = local.repository == "" ? "" : try(data.coder_parameter.git_branch[0].value, var.default_git_branch)
  deployment_name   = "coder-${data.coder_workspace.me.id}"
  home_claim_name   = "coder-${data.coder_workspace.me.id}-home"
  workspace_size    = local.workspace_sizes[data.coder_parameter.workspace_size.value]
  cpu_limit         = tostring(data.coder_parameter.customize_specs.value ? data.coder_parameter.cpu[0].value : local.workspace_size.cpu)
  memory_limit      = "${data.coder_parameter.customize_specs.value ? data.coder_parameter.memory[0].value : local.workspace_size.memory}Gi"
  home_storage_size = "${data.coder_parameter.home_disk_size.value}Gi"

  # CPU and memory requests intentionally match their limits so a selected
  # workspace size receives the capacity that Kubernetes schedules for it.
  ephemeral_storage_request = "2Gi"
  ephemeral_storage_limit   = "10Gi"
  tmp_size_limit            = "4Gi"

  labels = {
    "app.kubernetes.io/name"     = "coder-workspace"
    "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
    "app.kubernetes.io/part-of"  = "coder"
    "com.coder.resource"         = "true"
    "com.coder.workspace.id"     = data.coder_workspace.me.id
    "com.coder.workspace.name"   = data.coder_workspace.me.name
    "com.coder.user.id"          = data.coder_workspace_owner.me.id
    "com.coder.user.username"    = data.coder_workspace_owner.me.name
  }

  git_environment = local.repository == "" || var.git_auth_mode != "zarf-secret" ? [] : [
    {
      name = "ZARF_GIT_USERNAME"
      valueFrom = {
        secretKeyRef = {
          name = var.git_secret_name
          key  = "username"
        }
      }
    },
    {
      name = "ZARF_GIT_PASSWORD"
      valueFrom = {
        secretKeyRef = {
          name = var.git_secret_name
          key  = "password"
        }
      }
    },
  ]
}
