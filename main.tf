# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "k8s-agentic-ai-vpc"
    Environment = "production"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "k8s-agentic-ai-igw"
  }

  depends_on = [aws_vpc.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "k8s-agentic-ai-public-rt"
  }

  depends_on = [aws_internet_gateway.main]
}

# Public Subnets (EKS requires at least 2 subnets in different AZs)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-agentic-ai-public-subnet-1a"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-agentic-ai-public-subnet-1b"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ap-south-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-agentic-ai-public-subnet-1c"
    "kubernetes.io/role/elb" = "1"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_3" {
  subnet_id      = aws_subnet.public_3.id
  route_table_id = aws_route_table.public.id
}

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster" {
  name        = "k8s-agentic-ai-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-agentic-ai-eks-cluster-sg"
  }
}

# Security Group for Worker Nodes
resource "aws_security_group" "eks_nodes" {
  name        = "k8s-agentic-ai-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-agentic-ai-eks-nodes-sg"
  }
}

# Allow nodes to communicate with each other
resource "aws_security_group_rule" "eks_nodes_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

# EKS Cluster Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "k8s-agentic-ai-cluster"
  kubernetes_version = "1.31"

  # Account and partition info (required for plan-time evaluation)
  # Prevent dynamic evaluation of internal node group data sources
  # Note: Not standard module inputs, but passed through to submodules

  # Cluster endpoint access
  endpoint_public_access  = true
  endpoint_private_access = true

  # Networking
  vpc_id             = aws_vpc.main.id
  subnet_ids         = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id,
    aws_subnet.public_3.id
  ]
  control_plane_subnet_ids = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id,
    aws_subnet.public_3.id
  ]

  # Cluster addons
  addons = {
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          ASSIGN_IPV4_ON_LAUNCH = "true"
        }
      })
    }
  }

  # Managed Node Groups
  eks_managed_node_groups = {
    green = {
      name            = "k8s-nodes"
      use_name_prefix = false
      
      ami_type       = "AL2_x86_64"
      capacity_type  = "ON_DEMAND"
      instance_types = ["t3.xlarge"]

      min_size     = 1
      max_size     = 3
      desired_size = 2

      # Disk configuration
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            delete_on_termination = true
            encrypted             = true
          }
        }
      }

      # IAM role policies
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        CloudWatchAgentServerPolicy  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }

      # Tags
      tags = {
        Environment = "production"
        NodeGroup   = "green"
      }
    }
  }

  # Cluster tags
  tags = {
    Name        = "k8s-agentic-ai-cluster"
    Environment = "production"
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_internet_gateway.main,
    aws_route_table_association.public_1,
    aws_route_table_association.public_2,
    aws_route_table_association.public_3
  ]
}