data "coder_external_auth" "git" {
  count = var.git_auth_mode == "external-auth" && (local.repository != "" || local.dotfiles_url != "") ? 1 : 0

  id = var.git_external_auth_id
}
