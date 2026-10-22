resource "coder_metadata" "home" {
  resource_id = module.workspace.home_claim_id
  icon        = "/icon/database.svg"

  item {
    key   = "Size"
    value = local.home_storage_size
  }

  item {
    key   = "Mount path"
    value = "`/home/coder`"
  }
}
