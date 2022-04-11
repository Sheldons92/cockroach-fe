resource rke_cluster "cluster" {
  ssh_agent_auth     = true
  cluster_name = "cluster"
  # kubernetes_version = "v1.19.16-rancher1-2"
  dynamic "nodes" {

    for_each = var.rke_nodes

    content {
      user = nodes.value.user
      address = nodes.value.public_ip
      internal_address = nodes.value.private_ip
      role    = nodes.value.roles
    }
  
}
    cloud_provider {
      name = "aws"
    }
    services {
    kube_controller {
      extra_args = {
        cluster-signing-cert-file=  "/etc/kubernetes/ssl/kube-ca.pem"
        cluster-signing-key-file  = "/etc/kubernetes/ssl/kube-ca-key.pem"
      }
    }
    }
}


resource "local_file" "kube_cluster_yaml" {
  filename = "${path.root}/kube_config_cluster.yml"
  content  = rke_cluster.cluster.kube_config_yaml
}