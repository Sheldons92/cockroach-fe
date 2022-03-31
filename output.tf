output "rke_nodes" {
  value = module.rke_infra.rke_nodes
  sensitive = true
}