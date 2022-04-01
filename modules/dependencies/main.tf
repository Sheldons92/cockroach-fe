#CSI Driver for Storage provisioning
resource "helm_release" "aws-ebs-csi-driver" {
  name       = "aws-ebs-csi-driver"

  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace = "kube-system"

}

 resource "kubernetes_storage_class" "deploy-default-sc" {
   metadata {
     name = "gp3"
     annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
   }
   storage_provisioner = "ebs.csi.aws.com"
   reclaim_policy = "Retain"

   parameters = {
     "type" = "gp3"
   }
 }