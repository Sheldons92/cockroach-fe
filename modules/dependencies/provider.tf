# Helm provider
provider "helm" {
  kubernetes {
    host = var.rke_k8s.host
    client_certificate     = var.rke_k8s.client_certificate
    client_key             = var.rke_k8s.client_key
    cluster_ca_certificate = var.rke_k8s.cluster_ca_certificate
  }
}

provider "kubernetes" {
  host = var.rke_k8s.host
    client_certificate     = var.rke_k8s.client_certificate
    client_key             = var.rke_k8s.client_key
    cluster_ca_certificate = var.rke_k8s.cluster_ca_certificate
}

variable "cert_manager" {
  type = object({
    ns = string
    version = string
    chart_set = list(object({
      name = string
      value = string
    }))
  })
  default = {
    ns = "cert-manager"
    version = "v1.7.0"
    chart_set = [
      {
        name = "installCRDs"
        value = "true"
      }
    ]
  }
  description = "Cert-manager helm chart properties. Chart sets can be added using chart_set param"
}
