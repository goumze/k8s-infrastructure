output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version"
  value       = module.eks.cluster_version
}

output "node_groups" {
  description = "EKS managed node groups"
  value       = module.eks.eks_managed_node_groups
}
