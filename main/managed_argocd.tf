locals {
  managed_argocd_namespace = "argocd-managed"
  root_chart_path          = "${path.module}/../modules/multi-agent-fsi-blog/gitops/root"
  root_chart_hash          = sha256(join("", [for f in sort(tolist(fileset(local.root_chart_path, "**"))) : filesha256("${local.root_chart_path}/${f}")]))
}

# The AWS provider does not expose an Identity Center instance resource.
resource "aws_cloudformation_stack" "argocd_identity" {
  count = var.enable_argocd_identity ? 1 : 0

  name = "argocd-identity-center"
  template_body = jsonencode({
    Resources = {
      IdentityCenter = {
        Type = "AWS::SSO::Instance"
        Properties = {
          Name = "argocd-identity-center"
        }
      }
    }
    Outputs = {
      InstanceArn     = { Value = { "Fn::GetAtt" = ["IdentityCenter", "InstanceArn"] } }
      IdentityStoreId = { Value = { "Fn::GetAtt" = ["IdentityCenter", "IdentityStoreId"] } }
    }
  })

  lifecycle {
    prevent_destroy = false
    # precondition {
    #   condition     = var.argocd_identity_admin != null
    #   error_message = "Set argocd_identity_admin before enabling the Identity Center instance."
    # }
  }
}

resource "aws_identitystore_user" "argocd_admin" {
  count = var.enable_argocd_identity ? 1 : 0

  identity_store_id = aws_cloudformation_stack.argocd_identity[0].outputs["IdentityStoreId"]
  user_name         = try(var.argocd_identity_admin.user_name, null)
  display_name      = try(var.argocd_identity_admin.display_name, null)

  name {
    given_name  = try(var.argocd_identity_admin.given_name, null)
    family_name = try(var.argocd_identity_admin.family_name, null)
  }

  emails {
    value   = try(var.argocd_identity_admin.email, null)
    primary = true
  }

  lifecycle {
    prevent_destroy = false
  }
}

data "aws_iam_policy_document" "managed_argocd_assume_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["capabilities.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "managed_argocd" {
  count = var.enable_managed_argocd ? 1 : 0

  name               = "${module.cluster.cluster_name}-argocd-capability"
  assume_role_policy = data.aws_iam_policy_document.managed_argocd_assume_role.json
}

resource "time_sleep" "managed_argocd_role" {
  count = var.enable_managed_argocd ? 1 : 0

  create_duration = "30s"
  depends_on      = [aws_iam_role.managed_argocd]
}

resource "kubectl_manifest" "managed_argocd_namespace" {
  count = var.enable_managed_argocd ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata   = { name = local.managed_argocd_namespace }
  })
}

resource "aws_eks_capability" "managed_argocd" {
  count = var.enable_managed_argocd ? 1 : 0

  cluster_name              = module.cluster.cluster_name
  capability_name           = "argocd"
  type                      = "ARGOCD"
  role_arn                  = aws_iam_role.managed_argocd[0].arn
  delete_propagation_policy = "RETAIN"

  configuration {
    argo_cd {
      namespace = local.managed_argocd_namespace
      aws_idc {
        idc_instance_arn = try(aws_cloudformation_stack.argocd_identity[0].outputs["InstanceArn"], null)
        idc_region       = var.aws_region
      }
      rbac_role_mapping {
        role = "ADMIN"
        identity {
          id   = try(aws_identitystore_user.argocd_admin[0].user_id, null)
          type = "SSO_USER"
        }
      }
    }
  }

  lifecycle {
    prevent_destroy = false
    precondition {
      condition     = var.enable_argocd_identity && var.self_managed_argocd_paused
      error_message = "Enable Identity Center and pause the self-managed Argo CD controllers before the managed cutover."
    }
  }

  depends_on = [time_sleep.managed_argocd_role, kubectl_manifest.managed_argocd_namespace]
}

resource "aws_eks_access_policy_association" "managed_argocd" {
  count = var.enable_managed_argocd ? 1 : 0

  cluster_name  = module.cluster.cluster_name
  principal_arn = aws_iam_role.managed_argocd[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_capability.managed_argocd]
}

resource "kubectl_manifest" "managed_argocd_cluster" {
  count = var.enable_managed_argocd ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "local-cluster"
      namespace = local.managed_argocd_namespace
      labels    = { "argocd.argoproj.io/secret-type" = "cluster" }
    }
    type = "Opaque"
    stringData = {
      name    = "local-cluster"
      server  = module.cluster.cluster_arn
      project = "default"
    }
  })

  depends_on = [aws_eks_capability.managed_argocd, aws_eks_access_policy_association.managed_argocd]
}

data "http" "managed_argocd_jwks" {
  count = var.enable_managed_argocd ? 1 : 0
  url   = "${module.cluster.oidc_issuer_url}/keys"
}

resource "helm_release" "managed_root_apps" {
  count = var.enable_managed_argocd ? 1 : 0

  name      = "platform-root-managed"
  chart     = local.root_chart_path
  namespace = local.managed_argocd_namespace
  timeout   = 900
  values = [yamlencode({
    chartContentHash  = local.root_chart_hash
    basePath          = "modules/multi-agent-fsi-blog"
    destinationServer = module.cluster.cluster_arn
    gitOpsRepo = {
      url    = "https://github.com/goumze/k8s-infrastructure"
      branch = "feature/aws_eks_cluster_acks_kro"
    }
    ack = {
      clusterName = module.cluster.cluster_name
      region      = var.aws_region
    }
    eks = {
      oidcIssuer = module.cluster.oidc_issuer_url
      jwksJson   = base64encode(data.http.managed_argocd_jwks[0].response_body)
    }
  })]

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [kubectl_manifest.managed_argocd_cluster]
}

output "managed_argocd_server_url" {
  description = "AWS-managed Argo CD server URL after enabling the capability."
  value       = try(aws_eks_capability.managed_argocd[0].configuration[0].argo_cd[0].server_url, null)
}
