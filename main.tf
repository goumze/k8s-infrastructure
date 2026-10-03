data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
    "kubernetes.io/cluster/k8s-agentic-ai-cluster" = "shared"
  }
}

resource "aws_subnet" "public_subnet" {
 count                   = 2
 vpc_id                  = aws_vpc.main.id
 cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
 availability_zone       = data.aws_availability_zones.available.names[count.index]
 map_public_ip_on_launch = true

 tags = {
   Name = "public-subnet-${count.index}"
   "kubernetes.io/cluster/k8s-agentic-ai-cluster" = "shared"
   "kubernetes.io/role/elb"                        = "1"
 }
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  # Ensure EKS and all nodes are destroyed before detaching IGW
  depends_on = [module.eks]
  
  tags = {
    Name = "main-internet-gateway"
  }
}

resource "aws_route_table" "public" {
 vpc_id = aws_vpc.main.id

 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.main.id
 }

 tags = {
   Name = "main-route-table"
 }
}

resource "aws_route_table_association" "subnet_association" {
 count          = 2
 subnet_id      = aws_subnet.public_subnet.*.id[count.index]
 route_table_id = aws_route_table.public.id
 
 depends_on = [module.eks]
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "k8s-agentic-ai-cluster"
  kubernetes_version = "1.33"

  endpoint_public_access  = true
  endpoint_private_access = true

  # IMPORTANT: During destroy, run these commands manually:
  # terraform destroy -target='module.eks.aws_eks_node_group.this["green"]' -auto-approve
  # sleep 180
  # terraform destroy -auto-approve
  
  addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = aws_vpc.main.id
  subnet_ids               = aws_subnet.public_subnet.*.id
  control_plane_subnet_ids = aws_subnet.public_subnet.*.id

  eks_managed_node_groups = {
    green = {
      #ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 1
      desired_size = 1
      
      # Allow proper termination during destroy
      tags = {
        Name = "eks-node-green"
      }
      
      # Disable termination protection to allow clean shutdown
      disable_api_termination = false
    }
  }
}

#https://spacelift.io/blog/terraform-eks
#https://dev.to/aws-builders/building-an-amazon-eks-cluster-with-raw-terraform-resources-1gj0
#https://dev.to/aws-builders/building-an-amazon-eks-cluster-with-raw-terraform-resources-1gj0

