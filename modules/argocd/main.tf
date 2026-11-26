terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0"
    }
  }
}

# The gateway template base64-decodes eks.jwksJson, so the JWKS is re-encoded here.
data "http" "oidc_jwks" {
  url = "${var.oidc_issuer_url}/keys"
}

locals {
  root_chart_path = "${path.module}/../multi-agent-fsi-blog/gitops/root"
  root_chart_hash = sha256(join("", [for f in sort(tolist(fileset(local.root_chart_path, "**"))) : filesha256("${local.root_chart_path}/${f}")]))
}

# Argo CD is installed with Helm rather than the EKS managed capability, so it
# needs no IAM Identity Center prerequisite. The helm provider is configured in main/providers.tf.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.namespace
  create_namespace = true
  atomic           = true
  timeout          = 900
}

# App-of-apps root from modules/multi-agent-fsi-blog/gitops/root. It renders one Argo CD
# Application per addon, ordered by sync wave, and must be installed after Argo CD
# so the Application CRD exists.
resource "helm_release" "root_apps" {
  name      = "platform-root"
  chart     = local.root_chart_path
  namespace = var.namespace
  atomic    = true
  timeout   = 900

  values = [yamlencode({
    basePath         = "modules/multi-agent-fsi-blog"
    chartContentHash = local.root_chart_hash
    gitOpsRepo = {
      url    = var.gitops_repo_url
      branch = var.gitops_branch
    }
    ack = {
      clusterName = var.cluster_name
      region      = var.region
    }
    eks = {
      oidcIssuer = var.oidc_issuer_url
      jwksJson   = base64encode(data.http.oidc_jwks.response_body)
    }
  })]

  depends_on = [helm_release.argocd]
}
