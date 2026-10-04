# Data sources for AWS account and availability zones

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Local values for computed values
locals {
  cluster_name = "k8s-agentic-ai-cluster"
  
  common_tags = merge(
    var.tags,
    {
      CreatedAt = timestamp()
    }
  )
}
