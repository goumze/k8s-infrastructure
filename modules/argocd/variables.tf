variable "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart"
  type        = string
  default     = "10.18.2"
}

variable "namespace" {
  description = "Namespace Argo CD is installed into"
  type        = string
  default     = "argocd"
}

variable "cluster_name" {
  description = "EKS cluster name, passed to the financial-services chart"
  type        = string
}

variable "region" {
  description = "AWS region of the cluster"
  type        = string
}

variable "oidc_issuer_url" {
  description = "EKS OIDC issuer URL. The JWKS is fetched from it to validate ServiceAccount tokens at the Agent Gateway"
  type        = string
}

variable "gitops_repo_url" {
  description = "Git repository the Argo CD Applications read addon and app manifests from"
  type        = string
  default     = "https://github.com/goumze/k8s-infrastructure"
}

variable "gitops_branch" {
  description = "Branch of gitops_repo_url that contains modules/multi-agent-fsi-blog/"
  type        = string
  default     = "feature/aws_eks_cluster_acks_kro"
}
