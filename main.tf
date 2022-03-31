module "rke_infra" {
  source = "./modules/rke-infra-aws"

  aws_access_key       = var.aws_access_key
  aws_secret_key       = var.aws_secret_key
  aws_region           = var.aws_region
  prefix               = var.aws_prefix
  iam_instance_profile = var.iam_instance_profile
  clusterid            = var.clusterid

  node_master_count = var.node_master_count
  node_worker_count = var.node_worker_count
  node_all_count    = var.node_all_count
  route53_name      = var.route53_name
  route53_zone      = var.route53_zone
  deploy_lb         = var.deploy_lb

}

module "rke" {
  source     = "./modules/rke"
  
  rke_nodes  = "${module.rke_infra.rke_nodes}"

  depends_on = [module.rke_infra]

}

module "cockroachdb" {
  source     = "./modules/cockroachdb"

  rke_k8s = {
    host                   = module.rke.kubeconfig_api_server_url
    client_certificate     = module.rke.kubeconfig_client_cert
    client_key             = module.rke.kubeconfig_client_key
    cluster_ca_certificate = module.rke.kubeconfig_ca_crt
  }

}