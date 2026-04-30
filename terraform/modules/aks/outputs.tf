output "aks_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet identity (for ACR pull access)"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "aks_cluster_identity_principal_id" {
  description = "Principal ID of the AKS cluster identity"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "aks_host" {
  description = "AKS API server host"
  value       = azurerm_kubernetes_cluster.main.kube_config.0.host
  sensitive   = true
}

output "aks_client_certificate" {
  description = "AKS client certificate"
  value       = azurerm_kubernetes_cluster.main.kube_config.0.client_certificate
  sensitive   = true
}

output "aks_client_key" {
  description = "AKS client key"
  value       = azurerm_kubernetes_cluster.main.kube_config.0.client_key
  sensitive   = true
}

output "aks_cluster_ca_certificate" {
  description = "AKS cluster CA certificate"
  value       = azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate
  sensitive   = true
}

output "aks_kube_config_raw" {
  description = "Raw kubeconfig"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "node_resource_group" {
  description = "Resource group for AKS nodes"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "control_plane_identity_id" {
  description = "ID of the AKS control plane identity"
  value       = azurerm_user_assigned_identity.aks_control_plane.id
}

output "control_plane_identity_principal_id" {
  description = "Principal ID of the AKS control plane identity"
  value       = azurerm_user_assigned_identity.aks_control_plane.principal_id
}
