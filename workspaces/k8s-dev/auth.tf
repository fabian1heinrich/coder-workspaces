data "coder_external_auth" "git" {
  count = var.git_auth_mode == "external-auth" && (local.repository != "" || var.default_dotfiles_repository != "") ? 1 : 0

  id = var.git_external_auth_id
}
