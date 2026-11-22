# ============================================================================
# EKS CLUSTER
# ============================================================================

resource "aws_eks_cluster" "main" {
  name     = "k8s-agentic-ai-cluster"
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [var.cluster_security_group_id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Name        = "k8s-agentic-ai-cluster"
    Environment = "production"
  }
}

# ============================================================================
# EKS NODE GROUP
# ============================================================================

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "k8s-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["t3.xlarge"]
  capacity_type  = "ON_DEMAND"
  disk_size      = 100

  tags = {
    Name        = "k8s-node-group"
    Environment = "production"
  }

  lifecycle {
    create_before_destroy = true
  }
}