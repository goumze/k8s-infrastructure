variable "cluster_version" {
  type = string
}

variable "bootstrap_self_managed_addons" {
  description = "Preserve the existing cluster bootstrap setting; set false when creating a new Auto Mode cluster."
  type        = bool
  default     = true
}

variable "cluster_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "cluster_security_group_id" {
  type = string
}
