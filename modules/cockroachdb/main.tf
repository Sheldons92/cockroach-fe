resource "helm_release" "cockroach" {
  name       = "cockroachdb"

  repository = "https://charts.cockroachdb.com/"
  chart      = "cockroachdb"
  wait = false
  create_namespace = true
  namespace = "cockroach"
  version = "7.0.1"

}