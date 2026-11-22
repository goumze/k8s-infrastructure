output "public_subnet_ids" {
  value = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id,
    aws_subnet.public_3.id,
  ]
}

output "cluster_security_group_id" {
  value = aws_security_group.cluster_sg.id
}
