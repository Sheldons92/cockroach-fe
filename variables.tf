variable cluster_name {
  default = "rke"
}

variable clusterid {
  default = ""
}

variable kubernetes_version {
  default = "v1.19.16-rancher1-4"
}

variable aws_access_key {
  default = ""
}

variable aws_secret_key {
  default = ""
}

variable aws_prefix {
  default = ""
}

variable node_all_count {
  default = 1
}

variable node_master_count {
  default = 0
}

variable node_worker_count {
  default = 0
}

variable aws_region {
  default = "eu-west-2"
}

variable iam_instance_profile {
  default = "RancherK8SUnrestrictedCloudProviderRoleWithRoute53EU"
}

variable route53_name {
  default =""
}

variable route53_zone {
  default = ""
}

variable deploy_lb {
default  = "false"
}