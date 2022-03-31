resource "helm_release" "cockroachdb" {
  name       = "cockroachdb"

  repository = "https://charts.cockroachdb.com/"
  chart      = "cockroachdb"

}