variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "k8s-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = false
}

variable "cluster_version" {
  description = "Kubernetes cluster version"
  type        = string
  default     = "1.37"
}

variable "bootstrap_self_managed_addons" {
  description = "Keep true for the existing cluster; use false when creating a new Auto Mode cluster."
  type        = bool
  default     = true
}

variable "ci_principal_arn" {
  description = "IAM user or role ARN used by CI to apply RGDs (EKS access entry)"
  type        = string
  default     = null
}

variable "enable_argocd_identity" {
  description = "Create an account-level Identity Center instance and Argo CD administrator."
  type        = bool
  default     = false
}

variable "argocd_identity_admin" {
  description = "Identity Center administrator details. Set through a private tfvars file or environment variable."
  type = object({
    user_name    = string
    display_name = string
    given_name   = string
    family_name  = string
    email        = string
  })
  default   = null
  sensitive = true
}

variable "enable_managed_argocd" {
  description = "Create the managed Argo CD capability and managed GitOps applications."
  type        = bool
  default     = false
}

variable "self_managed_argocd_paused" {
  description = "Confirm the existing self-managed Argo CD controllers were paused before cutover."
  type        = bool
  default     = false
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 3
}

variable "node_instance_type" {
  description = "EC2 instance type for nodes"
  type        = string
  default     = "t3.xlarge"
}

variable "node_volume_size" {
  description = "EBS volume size for nodes in GB"
  type        = number
  default     = 100
}

variable "enable_cluster_autoscaling" {
  description = "Enable cluster autoscaling"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "k8s-cluster"
    ManagedBy   = "Terraform"
  }
}