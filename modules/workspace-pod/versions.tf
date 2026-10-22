terraform {
  required_version = "= 1.12.1"

  required_providers {
    kubernetes = {
      source  = "registry.terraform.io/hashicorp/kubernetes"
      version = "= 3.0.1"
    }
  }
}
