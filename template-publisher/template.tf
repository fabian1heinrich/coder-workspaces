locals {
  template_version       = "0.1.0"
  python_template_dir    = abspath("${path.module}/../workspaces/python")
  k8s_dev_template_dir   = abspath("${path.module}/../workspaces/k8s-dev")
  python_template_files  = sort(tolist(fileset(local.python_template_dir, "**")))
  k8s_dev_template_files = sort(tolist(fileset(local.k8s_dev_template_dir, "**")))

  common_template_variables = {
    namespace                   = var.coder_namespace
    code_server_image           = var.code_server_image
    home_storage_class          = var.home_storage_class
    image_pull_secret_name      = var.image_pull_secret_name
    git_secret_name             = var.git_secret_name
    git_base_url                = var.git_base_url
    git_auth_mode               = var.git_auth_mode
    git_external_auth_id        = var.git_external_auth_id
    platform_ca_config_map_name = var.platform_ca_config_map_name
  }
  python_template_variables = merge(local.common_template_variables, {
    workspace_image             = var.workspace_image
    dupe_trooper_image          = var.dupe_trooper_image
    deja_doc_image              = var.deja_doc_image
    vsix_image                  = var.vsix_image
    default_repository          = var.default_repository
    default_git_branch          = var.default_git_branch
    default_dotfiles_repository = var.default_dotfiles_repository
    default_dotfiles_branch     = var.default_dotfiles_branch
  })
  k8s_dev_template_variables = merge(local.common_template_variables, {
    workspace_image                 = var.k8s_workspace_image
    vsix_image                      = var.k8s_vsix_image
    kubernetes_service_account_name = var.kubernetes_service_account_name
    kubernetes_target_namespace     = var.kubernetes_target_namespace
    default_repository              = var.k8s_default_repository
    default_git_branch              = var.k8s_default_git_branch
  })

  common_tf_vars = [
    { name = "namespace", value = var.coder_namespace },
    { name = "code_server_image", value = var.code_server_image },
    { name = "home_storage_class", value = var.home_storage_class },
    { name = "image_pull_secret_name", value = var.image_pull_secret_name },
    { name = "git_secret_name", value = var.git_secret_name },
    { name = "git_base_url", value = var.git_base_url },
    { name = "git_auth_mode", value = var.git_auth_mode },
    { name = "git_external_auth_id", value = var.git_external_auth_id },
    { name = "platform_ca_config_map_name", value = var.platform_ca_config_map_name },
  ]
  python_tf_vars = concat(local.common_tf_vars, [
    { name = "workspace_image", value = var.workspace_image },
    { name = "dupe_trooper_image", value = var.dupe_trooper_image },
    { name = "deja_doc_image", value = var.deja_doc_image },
    { name = "vsix_image", value = var.vsix_image },
    { name = "default_repository", value = var.default_repository },
    { name = "default_git_branch", value = var.default_git_branch },
    { name = "default_dotfiles_repository", value = var.default_dotfiles_repository },
    { name = "default_dotfiles_branch", value = var.default_dotfiles_branch },
  ])
  k8s_dev_tf_vars = concat(local.common_tf_vars, [
    { name = "workspace_image", value = var.k8s_workspace_image },
    { name = "vsix_image", value = var.k8s_vsix_image },
    { name = "kubernetes_service_account_name", value = var.kubernetes_service_account_name },
    { name = "kubernetes_target_namespace", value = var.kubernetes_target_namespace },
    { name = "default_repository", value = var.k8s_default_repository },
    { name = "default_git_branch", value = var.k8s_default_git_branch },
  ])

  python_content_revision = substr(sha256(jsonencode({
    files = {
      for file in local.python_template_files : file => filesha256("${local.python_template_dir}/${file}")
    }
    variables = local.python_template_variables
  })), 0, 12)
  k8s_dev_content_revision = substr(sha256(jsonencode({
    files = {
      for file in local.k8s_dev_template_files : file => filesha256("${local.k8s_dev_template_dir}/${file}")
    }
    variables = local.k8s_dev_template_variables
  })), 0, 12)
  python_template_revision  = join("-", compact([local.python_content_revision, var.publish_id]))
  k8s_dev_template_revision = join("-", compact([local.k8s_dev_content_revision, var.publish_id]))
}

resource "coderd_template" "python_workspace" {
  name        = "python-workspace"
  description = "Air-gapped Python workspaces on Kubernetes"
  icon        = "/icon/python.svg"

  versions = [{
    directory = local.python_template_dir
    active    = true
    name      = "${local.template_version}-${local.python_template_revision}"
    tf_vars   = local.python_tf_vars
  }]
}

resource "coderd_template" "k8s_dev" {
  name        = "k8s-dev"
  description = "Air-gapped workspace for operating Kubernetes clusters"
  icon        = "/icon/k8s.svg"

  versions = [{
    directory = local.k8s_dev_template_dir
    active    = true
    name      = "${local.template_version}-${local.k8s_dev_template_revision}"
    tf_vars   = local.k8s_dev_tf_vars
  }]
}

moved {
  from = coderd_template.kubernetes_workspace
  to   = coderd_template.python_workspace
}
