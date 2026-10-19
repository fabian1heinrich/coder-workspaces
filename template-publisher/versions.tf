terraform {
  required_version = "= 1.12.1"

  required_providers {
    coderd = {
      source  = "registry.terraform.io/coder/coderd"
      version = "= 0.0.23"
    }
  }
}
