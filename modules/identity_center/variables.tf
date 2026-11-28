variable "region" {
  description = "Region where the account-level Identity Center instance is created and used."
  type        = string
}

variable "instance_name" {
  description = "Name given to the Identity Center instance when it is first created."
  type        = string
  default     = "k8s-agentic-ai-identity-center"
}

variable "admin" {
  description = "Identity Center user that receives Argo CD administrator access through the admin group."
  type = object({
    user_name    = string
    display_name = string
    given_name   = string
    family_name  = string
    email        = string
  })
}

variable "admin_group_name" {
  description = "Identity Center group mapped to the Argo CD ADMIN role."
  type        = string
  default     = "argocd-admins"
}
