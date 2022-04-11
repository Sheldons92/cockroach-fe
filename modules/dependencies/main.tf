#CSI Driver for Storage provisioning
resource "helm_release" "aws-ebs-csi-driver" {
  name       = "aws-ebs-csi-driver"

  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace = "kube-system"
  values = [
    "${file("${path.module}/files/values.yaml")}"
    ]
}

#Cert-Manager for Ingress TLS

resource "helm_release" "cert_manager" {
  repository = "https://charts.jetstack.io"
  name       = "jetstack"
  chart      = "cert-manager"
  version    = var.cert_manager.version
  namespace  = var.cert_manager.ns
  create_namespace = true

  dynamic set {
    for_each = var.cert_manager.chart_set
    content {
      name  = set.value.name
      value = set.value.value
    }
  }
}

#Hacky delay to allow SC to be deployed (Only needed due to doing everything in one big repo)
resource "time_sleep" "wait_30_seconds" {
  depends_on = [helm_release.cert_manager]
  create_duration = "30s"
}


#Temporary until I re-work kubernetes provider config
resource "null_resource" "add_letsencrypt_issuer" {
depends_on = [helm_release.cert_manager, time_sleep.wait_30_seconds]
  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/files/issuer.yml --kubeconfig=${path.root}/kube_config_cluster.yml"
  }
}