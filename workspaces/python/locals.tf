locals {
  default_home_disk_size  = 20
  default_enable_dotfiles = true

  workspace_images = merge(
    {
      "python-3.13" = {
        description = "Plain Python 3.13 development environment."
        reference   = var.workspace_image
      }
    },
    var.deja_doc_image == "" ? {} : {
      "deja-doc" = {
        description = "Turns unruly PDFs, DOCX files, and other proprietary formats into RAG- and MCP-ready AI knowledge—because even legacy files deserve a second career."
        reference   = var.deja_doc_image
      }
    },
    var.dupe_trooper_image == "" ? {} : {
      "dupe-trooper" = {
        description = "Patrols the file structure for duplicate files and sends the redundant clones packing."
        reference   = var.dupe_trooper_image
      }
    },
  )

  workspace_image_order = concat(
    ["python-3.13"],
    var.deja_doc_image == "" ? [] : ["deja-doc"],
    var.dupe_trooper_image == "" ? [] : ["dupe-trooper"],
  )

  projects = merge(
    {
      sandbox = {
        description      = "Plain Python 3.13 environment for general development."
        repository       = var.default_repository
        git_branch       = var.default_git_branch
        workspace_image  = var.workspace_image
        recommended_size = "standard"
      }
    },
    var.deja_doc_image == "" ? {} : {
      "deja-doc" = {
        description      = "Turns unruly PDFs, DOCX files, and other proprietary formats into RAG- and MCP-ready AI knowledge—because even legacy files deserve a second career."
        repository       = var.default_repository
        git_branch       = var.default_git_branch
        workspace_image  = var.deja_doc_image
        recommended_size = "standard"
      }
    },
    var.dupe_trooper_image == "" ? {} : {
      "dupe-trooper" = {
        description      = "Patrols the file structure for duplicate files and sends the redundant clones packing."
        repository       = var.default_repository
        git_branch       = var.default_git_branch
        workspace_image  = var.dupe_trooper_image
        recommended_size = "standard"
      }
    },
  )

  project_order = concat(
    var.deja_doc_image == "" ? [] : ["deja-doc"],
    var.dupe_trooper_image == "" ? [] : ["dupe-trooper"],
    ["sandbox"],
  )

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

  project              = local.projects[data.coder_parameter.project.value]
  is_sandbox           = data.coder_parameter.project.value == "sandbox"
  repository           = trim(local.is_sandbox ? try(data.coder_parameter.repository[0].value, "") : local.project.repository, "/")
  repository_parts     = local.repository == "" ? [] : split("/", local.repository)
  repository_name      = local.repository == "" ? "" : local.repository_parts[length(local.repository_parts) - 1]
  repository_url       = local.repository == "" ? "" : "${var.git_base_url}/${local.repository}.git"
  workspace_folder     = local.repository_name == "" ? "/home/coder" : "/home/coder/${local.repository_name}"
  git_branch           = local.repository == "" ? "" : (local.is_sandbox ? try(data.coder_parameter.git_branch[0].value, "") : local.project.git_branch)
  dotfiles_url         = var.default_dotfiles_repository == "" ? "" : "${var.git_base_url}/${var.default_dotfiles_repository}.git"
  deployment_name      = "coder-${data.coder_workspace.me.id}"
  home_claim_name      = "coder-${data.coder_workspace.me.id}-home"
  workspace_image_name = local.is_sandbox ? try(data.coder_parameter.workspace_image[0].value, "python-3.13") : data.coder_parameter.project.value
  workspace_image      = local.is_sandbox ? local.workspace_images[local.workspace_image_name].reference : local.project.workspace_image
  workspace_size       = local.workspace_sizes[data.coder_parameter.workspace_size.value]
  cpu_limit            = tostring(data.coder_parameter.customize_specs.value ? data.coder_parameter.cpu[0].value : local.workspace_size.cpu)
  memory_limit         = "${data.coder_parameter.customize_specs.value ? data.coder_parameter.memory[0].value : local.workspace_size.memory}Gi"
  home_storage_size    = "${try(data.coder_parameter.home_disk_size[0].value, local.default_home_disk_size)}Gi"
  enable_dotfiles      = try(data.coder_parameter.enable_dotfiles[0].value, local.default_enable_dotfiles)

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
