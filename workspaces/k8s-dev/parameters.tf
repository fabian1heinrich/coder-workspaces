data "coder_parameter" "repository" {
  count = var.git_base_url == "" ? 0 : 1

  name         = "repository"
  display_name = "Repository"
  description  = "Owner/repository path in the configured Git service. Leave empty to start without cloning a repository."
  type         = "string"
  default      = var.default_repository
  order        = 1
  mutable      = false
  icon         = "/icon/git.svg"

  validation {
    regex = "^$|^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$"
    error = "Use an empty value or an owner/repository path containing only letters, digits, dots, underscores, and hyphens."
  }
}

data "coder_parameter" "git_branch" {
  count = local.repository == "" ? 0 : 1

  name         = "git_branch"
  display_name = "Source revision"
  description  = "Branch or revision to clone from the repository."
  type         = "string"
  default      = var.default_git_branch
  order        = 2
  mutable      = false
  icon         = "/icon/git.svg"

  validation {
    regex = "^[A-Za-z0-9._/-]+$"
    error = "Source revisions may contain letters, digits, dots, underscores, slashes, and hyphens."
  }
}

data "coder_parameter" "workspace_size" {
  name         = "workspace_size"
  display_name = "Workspace size"
  description  = "Choose the scheduled CPU and memory capacity for the workspace."
  type         = "string"
  form_type    = "dropdown"
  default      = "standard"
  order        = 3
  mutable      = true
  icon         = "/icon/memory.svg"

  dynamic "option" {
    for_each = local.workspace_sizes

    content {
      name        = option.value.display_name
      description = "${option.value.cpu} CPU ${option.value.cpu == 1 ? "core" : "cores"} and ${option.value.memory} GiB of memory"
      value       = option.key
      icon        = "/icon/memory.svg"
    }
  }
}

data "coder_parameter" "customize_specs" {
  name         = "customize_specs"
  display_name = "Customize specifications"
  description  = "Override the selected workspace size with custom CPU and memory values."
  type         = "bool"
  form_type    = "switch"
  default      = false
  order        = 4
  mutable      = true
  icon         = "/icon/memory.svg"
}

data "coder_parameter" "cpu" {
  count = data.coder_parameter.customize_specs.value ? 1 : 0

  name         = "cpu"
  display_name = "CPU cores"
  description  = "CPU request and limit for the workspace container."
  type         = "number"
  form_type    = "slider"
  default      = local.workspace_size.cpu
  order        = 5
  mutable      = true
  icon         = "/icon/memory.svg"

  validation {
    min = 1
    max = 8
  }
}

data "coder_parameter" "memory" {
  count = data.coder_parameter.customize_specs.value ? 1 : 0

  name         = "memory"
  display_name = "Memory (GiB)"
  description  = "Memory request and limit for the workspace container."
  type         = "number"
  form_type    = "slider"
  default      = local.workspace_size.memory
  order        = 6
  mutable      = true
  icon         = "/icon/memory.svg"

  validation {
    min = 2
    max = 32
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Persistent home disk (GiB)"
  description  = "Size of the persistent /home/coder directory. It can be increased when the StorageClass supports expansion, but cannot be reduced."
  type         = "number"
  form_type    = "slider"
  default      = local.default_home_disk_size
  order        = 7
  mutable      = true
  icon         = "/emojis/1f4be.png"

  validation {
    min       = 10
    max       = 200
    monotonic = "increasing"
  }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
