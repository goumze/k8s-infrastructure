variable "cluster_name" {
  description = "Name of the existing EKS cluster the capabilities are attached to"
  type        = string
}

variable "tags" {
  description = "Tags applied to the capability IAM roles and capabilities"
  type        = map(string)
  default     = {}
}

variable "ci_principal_arn" {
  description = "Optional IAM user or role ARN granted cluster admin via an EKS access entry. Null skips it."
  type        = string
  default     = null
}
