output "home_claim_id" {
  description = "Resource ID of the persistent home claim, for coder_metadata."
  value       = kubernetes_persistent_volume_claim_v1.home.id
}

output "home_claim_name" {
  description = "Name of the persistent home claim."
  value       = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
}
