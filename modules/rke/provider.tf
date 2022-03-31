terraform {
  required_providers {
    rke = {
      source  = "rancher/rke"
      version = "1.3.0"
    }
  }
  required_version = ">= 0.13"
}

# provider "kubernetes" {
#   kubernetes {
#     host = var.rke_k8s.host
#     client_certificate     = var.rke_k8s.client_certificate
#     client_key             = var.rke_k8s.client_key
#     cluster_ca_certificate = var.rke_k8s.cluster_ca_certificate
#   }
# }