data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
 cidr_block = "10.0.0.0/16"

 tags = {
   Name = "main-vpc-eks"
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
 }
}

resource "aws_internet_gateway" "main" {
 vpc_id = aws_vpc.main.id

 tags = {
   Name = "main-igw"
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

resource "aws_route_table_association" "a" {
 count          = 2
 subnet_id      = aws_subnet.public_subnet.*.id[count.index]
 route_table_id = aws_route_table.public.id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "k8s-agentic-ai-cluster"
  kubernetes_version = "1.33"

  endpoint_public_access  = true
  #endpoint_private_access = true
  enable_cluster_creator_admin_permissions = true

  # IMPORTANT: During destroy, run these commands manually:
  # terraform destroy -target='module.eks.aws_eks_node_group.this["green"]' -auto-approve
  # sleep 180
  # terraform destroy -auto-approve
  
  # addons = {
  #   coredns = {
  #     most_recent = true
  #   }
  #   kube-proxy = {
  #     most_recent = true
  #   }
  #   vpc-cni = {
  #     most_recent = true
  #   }
  # }

  vpc_id                   = aws_vpc.main.id
  subnet_ids               = aws_subnet.public_subnet.*.id
  #control_plane_subnet_ids = aws_subnet.public_subnet.*.id

  eks_managed_node_groups = {
    green = {
      instance_types = ["t3.medium"]
      min_size     = 1
      max_size     = 3
      desired_size = 2
      # Allow proper termination during destroy
      tags = {
        Name = "eks-node-green"
      }
      
      # Disable termination protection to allow clean shutdown
      disable_api_termination = false
    }
  }
}

# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "~> 21.0"

#   name               = "my-cluster"
#   kubernetes_version = "1.33"

#   enable_cluster_creator_admin_permissions = true

#   vpc_id     = aws_vpc.main.id
#   subnet_ids = aws_subnet.public_subnet.*.id

#   eks_managed_node_groups = {
#     example = {
#       ami_type       = "AL2023_x86_64_STANDARD"
#       instance_types = ["m5.xlarge"]

#       min_size     = 2
#       max_size     = 10
#       desired_size = 2
#     }
#   }
# }

#https://spacelift.io/blog/terraform-eks
#https://dev.to/aws-builders/building-an-amazon-eks-cluster-with-raw-terraform-resources-1gj0
#https://dev.to/aws-builders/building-an-amazon-eks-cluster-with-raw-terraform-resources-1gj0

