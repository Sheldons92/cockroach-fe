# Helm provider
provider "helm" {
  kubernetes {
    host = var.rke_k8s.host
    client_certificate     = var.rke_k8s.client_certificate
    client_key             = var.rke_k8s.client_key
    cluster_ca_certificate = var.rke_k8s.cluster_ca_certificate
  # kubernetes {
  #   config_path = "./kube_config_cluster.yml"
  }
}

provider "kubernetes" {
config_path    = "./kube_config_cluster.yml"
}