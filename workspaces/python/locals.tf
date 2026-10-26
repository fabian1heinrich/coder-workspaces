locals {
  default_home_disk_size  = 20
  default_enable_dotfiles = true

  # Sandbox users choose registry-relative image references. Keep the registry
  # itself deployment-owned and derive the editable defaults from the images
  # supplied when the template is published.
  image_registry                    = split("/", var.sandbox_image)[0]
  workspace_image_parts             = split("/", var.sandbox_image)
  code_server_image_parts           = split("/", var.code_server_image)
  vsix_image_parts                  = split("/", var.vsix_image)
  default_workspace_image_reference = length(local.workspace_image_parts) > 1 ? join("/", slice(local.workspace_image_parts, 1, length(local.workspace_image_parts))) : var.sandbox_image
  default_code_server_reference     = length(local.code_server_image_parts) > 1 ? join("/", slice(local.code_server_image_parts, 1, length(local.code_server_image_parts))) : var.code_server_image
  default_vsix_reference            = length(local.vsix_image_parts) > 1 ? join("/", slice(local.vsix_image_parts, 1, length(local.vsix_image_parts))) : var.vsix_image

  # Projects are declared once in projects.json, which this template carries
  # and the build and CI read. Each project has its own deployment-supplied
  # image and repository, and becomes selectable when its image is set.
  project_catalog = {
    for entry in jsondecode(file("${path.module}/projects.json")) : entry.name => entry
  }

  project_profiles = {
    "deja-doc" = {
      workspace_image = var.deja_doc_image
      repository      = var.deja_doc_repository
    }
    "dupe-trooper" = {
      workspace_image = var.dupe_trooper_image
      repository      = var.dupe_trooper_repository
    }
  }

  enabled_projects = {
    for name, profile in local.project_profiles : name => {
      description      = local.project_catalog[name].description
      recommended_size = local.project_catalog[name].recommended_size
      workspace_image  = profile.workspace_image
      repository       = var.git_base_url == "" ? "" : profile.repository
      git_branch       = var.default_git_branch
    } if profile.workspace_image != ""
  }

  projects = merge(
    {
      sandbox = {
        description      = "Plain Python 3.13 environment for general development."
        recommended_size = "standard"
        workspace_image  = var.sandbox_image
        repository       = var.git_base_url == "" ? "" : var.sandbox_repository
        git_branch       = var.default_git_branch
      }
    },
    local.enabled_projects,
  )

  # Projects first, so the plain environment sorts last in the picker.
  project_order = concat(sort(keys(local.enabled_projects)), ["sandbox"])

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
  repository           = trim(try(data.coder_parameter.repository[0].value, ""), "/")
  repository_parts     = local.repository == "" ? [] : split("/", local.repository)
  repository_name      = local.repository == "" ? "" : local.repository_parts[length(local.repository_parts) - 1]
  repository_url       = local.repository == "" ? "" : "${var.git_base_url}/${local.repository}.git"
  workspace_folder     = local.repository_name == "" ? "/home/coder" : "/home/coder/${local.repository_name}"
  git_branch           = local.repository == "" ? "" : try(data.coder_parameter.git_branch[0].value, "")
  dotfiles_url         = var.git_base_url == "" || var.default_dotfiles_repository == "" ? "" : "${var.git_base_url}/${var.default_dotfiles_repository}.git"
  deployment_name      = "coder-${data.coder_workspace.me.id}"
  home_claim_name      = "coder-${data.coder_workspace.me.id}-home"
  workspace_image_name = local.is_sandbox ? "python-3.13" : data.coder_parameter.project.value
  workspace_image      = local.is_sandbox ? "${local.image_registry}/${data.coder_parameter.workspace_image[0].value}" : local.project.workspace_image
  code_server_image    = local.is_sandbox ? "${local.image_registry}/${data.coder_parameter.code_server_image[0].value}" : var.code_server_image
  vsix_image           = local.is_sandbox ? "${local.image_registry}/${data.coder_parameter.vsix_image[0].value}" : var.vsix_image
  workspace_size       = local.workspace_sizes[data.coder_parameter.workspace_size.value]
  cpu_limit            = tostring(data.coder_parameter.customize_specs.value ? data.coder_parameter.cpu[0].value : local.workspace_size.cpu)
  memory_limit         = "${data.coder_parameter.customize_specs.value ? data.coder_parameter.memory[0].value : local.workspace_size.memory}Gi"
  home_storage_size    = "${data.coder_parameter.home_disk_size.value}Gi"
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

  # A Deployment selector is immutable. It carries only the stable workspace
  # identity so that a workspace rename or a username change cannot invalidate
  # an existing Deployment.
  selector_labels = {
    "app.kubernetes.io/name" = "coder-workspace"
    "com.coder.workspace.id" = data.coder_workspace.me.id
  }
}
