data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "capability_assume_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["capabilities.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ack" {
  name               = "${var.cluster_name}-ack-capability"
  assume_role_policy = data.aws_iam_policy_document.capability_assume_role.json
  tags               = var.tags
}

# ACK controller permissions for AgentCore resources created from the RGDs.
data "aws_iam_policy_document" "ack_agentcore" {
  statement {
    actions = ["bedrock-agentcore:*"]
    resources = [
      "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }
}

resource "aws_iam_role_policy" "ack_agentcore" {
  name   = "agentcore-access"
  role   = aws_iam_role.ack.id
  policy = data.aws_iam_policy_document.ack_agentcore.json
}

resource "aws_iam_role" "kro" {
  name               = "${var.cluster_name}-kro-capability"
  assume_role_policy = data.aws_iam_policy_document.capability_assume_role.json
  tags               = var.tags
}

resource "aws_eks_capability" "ack" {
  cluster_name              = var.cluster_name
  capability_name           = "ack"
  type                      = "ACK"
  role_arn                  = aws_iam_role.ack.arn
  delete_propagation_policy = "RETAIN"
  tags                      = var.tags

  depends_on = [aws_iam_role_policy.ack_agentcore]
}

resource "aws_eks_capability" "kro" {
  cluster_name              = var.cluster_name
  capability_name           = "kro"
  type                      = "KRO"
  role_arn                  = aws_iam_role.kro.arn
  delete_propagation_policy = "RETAIN"
  tags                      = var.tags
}

resource "aws_eks_access_entry" "ci" {
  count = var.ci_principal_arn == null ? 0 : 1

  cluster_name  = var.cluster_name
  principal_arn = var.ci_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "ci" {
  count = var.ci_principal_arn == null ? 0 : 1

  cluster_name  = var.cluster_name
  principal_arn = var.ci_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.ci]
}

# RGDs are applied with kubectl_manifest, which does not need the kro CRDs
# at plan time (unlike kubernetes_manifest), so a fresh cluster can plan.
resource "kubectl_manifest" "rgd" {
  for_each = fileset("${path.module}/rgds", "*.yaml")

  yaml_body = file("${path.module}/rgds/${each.value}")

  depends_on = [aws_eks_capability.kro, aws_eks_capability.ack]
}
