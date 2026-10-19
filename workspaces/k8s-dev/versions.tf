terraform {
  required_version = "= 1.12.1"

  required_providers {
    coder = {
      source  = "registry.terraform.io/coder/coder"
      version = "= 2.18.0"
    }
    kubernetes = {
      source  = "registry.terraform.io/hashicorp/kubernetes"
      version = "= 3.0.1"
    }
  }
}

provider "coder" {}

provider "kubernetes" {
  # Coder's built-in provisioners run in the target cluster and use in-cluster auth.
}
