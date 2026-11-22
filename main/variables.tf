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

variable "ci_principal_arn" {
  description = "IAM user or role ARN used by CI to apply RGDs (EKS access entry)"
  type        = string
  default     = null
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