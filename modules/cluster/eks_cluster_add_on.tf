# ============================================================================
# EKS ADDONS
# ============================================================================

# VPC CNI, kube-proxy and CoreDNS are managed by EKS Auto Mode and must not
# be installed as add-ons on an Auto Mode cluster.

# Required for EKS Pod Identity associations used by the agent workloads.
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"

  tags = {
    Name = "k8s-pod-identity-agent-addon"
  }
}