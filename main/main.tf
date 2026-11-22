#Setup IAM
module "iam" {
  source = "../modules/iam"
}

#Setup VPC
module "vpc" {
  source     = "../modules/network/vpc"
  depends_on = [module.iam]
}

#Setup Internet Gateway for the VPC
module "igw" {
  source     = "../modules/network/internet_gateway"
  depends_on = [module.vpc]
}

#Setup subnets for the VPC
module "subnets" {
  source     = "../modules/network/subnets"
  depends_on = [module.vpc]
}

#Setup route_table
module "route_table" {
  source     = "../modules/network/route_table"
  depends_on = [module.subnets]
}

#Setup security_group
module "security_group" {
  source     = "../modules/network/security_group"
  depends_on = [module.route_table]
}

#setup cluster
module "cluster" {
  source     = "../modules/eks/cluster"
  depends_on = [module.security_group]
}

#setup eks addon
module "eks_addon" {
  source     = "../modules/eks/addon"
  depends_on = [module.cluster]
}













