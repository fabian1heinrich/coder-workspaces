data "coder_parameter" "project" {
  name         = "project"
  display_name = "Project"
  description = join("\n", concat(
    ["Choose a project:"],
    [for project_name in local.project_order : "- **${project_name}** — ${local.projects[project_name].description}"],
  ))
  type      = "string"
  form_type = "dropdown"
  default   = "sandbox"
  order     = 1
  mutable   = false
  icon      = "/icon/python.svg"

  dynamic "option" {
    for_each = local.project_order

    content {
      name        = option.value
      description = local.projects[option.value].description
      value       = option.value
      icon        = "/icon/python.svg"
    }
  }
}

data "coder_parameter" "repository" {
  count = var.git_base_url != "" ? 1 : 0

  name         = "repository"
  display_name = "Repository"
  description  = "Owner/repository path in the configured Git service. Leave empty to start without cloning a repository."
  type         = "string"
  default      = local.project.repository
  order        = 2
  mutable      = false
  icon         = "/icon/git.svg"

  validation {
    regex = "^$|^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$"
    error = "Use an empty value or an owner/repository path containing only letters, digits, dots, underscores, and hyphens."
  }
}

data "coder_parameter" "git_branch" {
  count = try(data.coder_parameter.repository[0].value, "") != "" ? 1 : 0

  name         = "git_branch"
  display_name = "Source revision"
  description  = "Branch or revision to clone from the repository."
  type         = "string"
  default      = var.default_git_branch
  order        = 3
  mutable      = false
  icon         = "/icon/git.svg"

  validation {
    regex = "^[A-Za-z0-9._/-]+$"
    error = "Source revisions may contain letters, digits, dots, underscores, slashes, and hyphens."
  }
}

data "coder_parameter" "workspace_image" {
  count = data.coder_parameter.project.value == "sandbox" ? 1 : 0

  name         = "workspace_image"
  display_name = "Workspace image"
  description  = "Registry-relative workspace image reference. ${local.image_registry}/ is prefixed automatically."
  type         = "string"
  default      = local.default_workspace_image_reference
  order        = 4
  mutable      = true
  icon         = "/icon/python.svg"

  validation {
    regex = "^[a-z0-9][a-z0-9._/-]*(:[A-Za-z0-9_][A-Za-z0-9._-]*)?@sha256:[0-9a-f]{64}$"
    error = "Use a registry-relative image reference pinned with @sha256:<64 lowercase hex characters>."
  }
}

data "coder_parameter" "code_server_image" {
  count = data.coder_parameter.project.value == "sandbox" ? 1 : 0

  name         = "code_server_image"
  display_name = "code-server image"
  description  = "Registry-relative code-server image-volume reference. ${local.image_registry}/ is prefixed automatically."
  type         = "string"
  default      = local.default_code_server_reference
  order        = 5
  mutable      = true
  icon         = "/icon/code.svg"

  validation {
    regex = "^[a-z0-9][a-z0-9._/-]*(:[A-Za-z0-9_][A-Za-z0-9._-]*)?@sha256:[0-9a-f]{64}$"
    error = "Use a registry-relative image reference pinned with @sha256:<64 lowercase hex characters>."
  }
}

data "coder_parameter" "vsix_image" {
  count = data.coder_parameter.project.value == "sandbox" ? 1 : 0

  name         = "vsix_image"
  display_name = "Extensions image"
  description  = "Registry-relative VSIX image-volume reference. ${local.image_registry}/ is prefixed automatically."
  type         = "string"
  default      = local.default_vsix_reference
  order        = 6
  mutable      = true
  icon         = "/icon/extensions.svg"

  validation {
    regex = "^[a-z0-9][a-z0-9._/-]*(:[A-Za-z0-9_][A-Za-z0-9._-]*)?@sha256:[0-9a-f]{64}$"
    error = "Use a registry-relative image reference pinned with @sha256:<64 lowercase hex characters>."
  }
}

data "coder_parameter" "cpu" {
  count = data.coder_parameter.customize_specs.value ? 1 : 0

  name         = "cpu"
  display_name = "CPU cores"
  description  = "CPU request and limit for the workspace container."
  type         = "number"
  form_type    = "slider"
  default      = local.workspace_size.cpu
  order        = 9
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
  order        = 10
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
  order        = 11
  mutable      = true
  icon         = "/emojis/1f4be.png"

  validation {
    min       = 10
    max       = 200
    monotonic = "increasing"
  }
}

data "coder_parameter" "enable_dotfiles" {
  count = data.coder_parameter.customize_specs.value ? 1 : 0

  name         = "enable_dotfiles"
  display_name = "Configure dotfiles"
  description  = "Apply the centrally packaged dotfiles when the workspace starts."
  type         = "bool"
  form_type    = "switch"
  default      = local.default_enable_dotfiles
  order        = 12
  mutable      = true
  icon         = "/icon/dotfiles.svg"
}

data "coder_parameter" "workspace_size" {
  name         = "workspace_size"
  display_name = "Workspace Size"
  description  = "Choose the scheduled CPU and memory capacity for the workspace."
  type         = "string"
  form_type    = "dropdown"
  default      = local.project.recommended_size
  order        = 7
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
  description  = "Override the selected workspace size with custom CPU and memory values, and change the dotfiles default."
  type         = "bool"
  form_type    = "switch"
  default      = false
  order        = 8
  mutable      = true
  icon         = "/icon/memory.svg"
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
