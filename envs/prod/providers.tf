provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = local.cluster_certificate_authority_data != "" ? base64decode(local.cluster_certificate_authority_data) : null

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = local.cluster_name != "" ? ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.aws_region] : []
  }
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = local.cluster_certificate_authority_data != "" ? base64decode(local.cluster_certificate_authority_data) : null

    exec {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = local.cluster_name != "" ? ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.aws_region] : []
    }
  }
}