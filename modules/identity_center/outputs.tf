output "instance_arn" {
  description = "ARN of the account-level IAM Identity Center instance."
  value       = local.instance_arn
}

output "admin_group_id" {
  description = "Identity Store group ID for Argo CD administrators."
  value       = aws_identitystore_group.admins.group_id
}
