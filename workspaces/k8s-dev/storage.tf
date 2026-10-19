resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = local.home_claim_name
    namespace = var.namespace
    labels    = local.labels
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  wait_until_bound = false

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.home_storage_class == "" ? null : var.home_storage_class

    resources {
      requests = {
        storage = local.home_storage_size
      }
    }
  }
}

resource "coder_metadata" "home" {
  resource_id = kubernetes_persistent_volume_claim_v1.home.id
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
