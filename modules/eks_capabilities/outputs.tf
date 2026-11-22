output "ack_capability_arn" {
  description = "ARN of the ACK EKS capability"
  value       = aws_eks_capability.ack.arn
}

output "kro_capability_arn" {
  description = "ARN of the KRO EKS capability"
  value       = aws_eks_capability.kro.arn
}
