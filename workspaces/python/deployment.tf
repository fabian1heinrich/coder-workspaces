# The workspace Pod and its persistent home come from the repository-owned
# shared module bundled in the template archive, so this template declares only
# what is specific to a Python workspace.
module "workspace" {
  source = "./workspace-pod"

  start_count     = data.coder_workspace.me.start_count
  namespace       = var.namespace
  deployment_name = local.deployment_name
  home_claim_name = local.home_claim_name
  labels          = local.labels
  selector_labels = local.selector_labels
  owner_email     = data.coder_workspace_owner.me.email

  home_storage_class = var.home_storage_class
  home_storage_size  = local.home_storage_size

  workspace_image        = local.workspace_image
  code_server_image      = local.code_server_image
  vsix_image             = local.vsix_image
  image_pull_secret_name = var.image_pull_secret_name

  cpu                       = local.cpu_limit
  memory                    = local.memory_limit
  ephemeral_storage_request = local.ephemeral_storage_request
  ephemeral_storage_limit   = local.ephemeral_storage_limit
  tmp_size_limit            = local.tmp_size_limit

  # Unlike k8s-dev, the root filesystem stays writable: project images keep
  # their offline uv cache at /opt/uv-cache, and uv writes there while
  # materializing an environment.
  read_only_root_filesystem = false

  platform_ca_config_map_name = var.platform_ca_config_map_name
  git_auth_mode               = local.repository == "" && local.dotfiles_url == "" ? "anonymous" : var.git_auth_mode
  git_base_url                = var.git_base_url
  git_credentials_secret_name = var.git_credentials_secret_name

  startup_commands  = ["workspace-startup /home/coder/.venv"]
  agent_init_script = coder_agent.main.init_script
  agent_token       = coder_agent.main.token
}
