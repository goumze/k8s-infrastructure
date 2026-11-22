# Per-agent AgentCore resources, identities and Kubernetes objects.
# Assumed from the blog: the orchestrator uses Memory only, the three specialists
# also use Code Interpreter, and market-data also uses Browser.

locals {
  namespace = "financial-services"

  agents = {
    financial-advisor = { capabilities = ["memory"] }
    portfolio-analyst = { capabilities = ["memory", "code_interpreter"] }
    risk-assessment   = { capabilities = ["memory", "code_interpreter"] }
    market-data       = { capabilities = ["memory", "code_interpreter", "browser"] }
  }

  agentcore_resource_types = {
    memory           = "memory"
    code_interpreter = "code-interpreter"
    browser          = "browser"
  }

  agentcore_actions = {
    memory = [
      "bedrock-agentcore:CreateEvent",
      "bedrock-agentcore:GetEvent",
      "bedrock-agentcore:ListEvents",
      "bedrock-agentcore:DeleteEvent",
      "bedrock-agentcore:RetrieveMemoryRecords",
      "bedrock-agentcore:ListMemoryRecords",
      "bedrock-agentcore:GetMemoryRecord",
      "bedrock-agentcore:DeleteMemoryRecord",
      "bedrock-agentcore:ListSessions",
    ]
    code_interpreter = [
      "bedrock-agentcore:StartCodeInterpreterSession",
      "bedrock-agentcore:InvokeCodeInterpreter",
      "bedrock-agentcore:StopCodeInterpreterSession",
      "bedrock-agentcore:GetCodeInterpreterSession",
      "bedrock-agentcore:ListCodeInterpreterSessions",
    ]
    browser = [
      "bedrock-agentcore:StartBrowserSession",
      "bedrock-agentcore:StopBrowserSession",
      "bedrock-agentcore:GetBrowserSession",
      "bedrock-agentcore:ListBrowserSessions",
      "bedrock-agentcore:UpdateBrowserStream",
      "bedrock-agentcore:ConnectBrowserAutomationStream",
      "bedrock-agentcore:ConnectBrowserLiveViewStream",
    ]
  }
}

resource "kubectl_manifest" "namespace" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata   = { name = local.namespace }
  })
}

resource "kubectl_manifest" "agent_service_account" {
  for_each = local.agents

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "${each.key}-sa"
      namespace = local.namespace
    }
  })

  depends_on = [kubectl_manifest.namespace]
}

# Pod Identity roles, one per agent. The trust policy is for EKS Pod Identity,
# which is the mechanism the blog uses instead of IRSA.
data "aws_iam_policy_document" "pod_identity_assume_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "agent" {
  for_each = local.agents

  name               = "${var.cluster_name}-${each.key}-agent"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume_role.json
  tags               = var.tags
}

# Action-level scoping per capability. The resource is account-wide for each
# AgentCore resource type, because instance ARNs are only known after kro creates them.
data "aws_iam_policy_document" "agent" {
  for_each = local.agents

  statement {
    sid = "BedrockInvoke"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:Converse",
      "bedrock:ConverseStream",
    ]
    resources = [
      "arn:aws:bedrock:*::foundation-model/*",
      "arn:aws:bedrock:*:*:inference-profile/*",
    ]
  }

  dynamic "statement" {
    for_each = each.value.capabilities
    content {
      actions = local.agentcore_actions[statement.value]
      resources = [
        "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${local.agentcore_resource_types[statement.value]}/*"
      ]
    }
  }
}

resource "aws_iam_role_policy" "agent" {
  for_each = local.agents

  name   = "agentcore-access"
  role   = aws_iam_role.agent[each.key].id
  policy = data.aws_iam_policy_document.agent[each.key].json
}

resource "aws_eks_pod_identity_association" "agent" {
  for_each = local.agents

  cluster_name    = var.cluster_name
  namespace       = local.namespace
  service_account = "${each.key}-sa"
  role_arn        = aws_iam_role.agent[each.key].arn

  depends_on = [kubectl_manifest.agent_service_account]
}
