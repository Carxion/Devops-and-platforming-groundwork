output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "resource_group_name" {
  value = azurerm_resource_group.aks.name
}

output "oidc_issuer_url" {
  description = "Use when creating federated credentials for workload identity."
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Grant AcrPull on your registry to this identity."
  value       = one(azurerm_kubernetes_cluster.main.kubelet_identity[*].object_id)
}

output "kubeconfig_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.aks.name} --name ${azurerm_kubernetes_cluster.main.name} && kubelogin convert-kubeconfig -l azurecli"
}
