# ============================================================================
# EKS CLUSTER
# ============================================================================

resource "aws_eks_cluster" "main" {
  name     = "k8s-agentic-ai-cluster"
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  bootstrap_self_managed_addons = var.bootstrap_self_managed_addons

  compute_config {
    enabled       = true
    node_pools    = ["general-purpose", "system"]
    node_role_arn = var.node_role_arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [var.cluster_security_group_id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # API mode uses EKS access entries only; the aws-auth ConfigMap is not read.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name        = "k8s-agentic-ai-cluster"
    Environment = "production"
  }
}