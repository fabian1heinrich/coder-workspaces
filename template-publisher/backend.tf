terraform {
  # Runtime backend settings come from the publisher Job. OpenTofu stores
  # state in a namespace-scoped Secret and coordinates writes with a Lease.
  backend "kubernetes" {}
}
