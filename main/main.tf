module "iam" {
  source = "../modules/iam"
}

module "network" {
  source     = "../modules/network"
  depends_on = [module.iam]
}

module "cluster" {
  source = "../modules/cluster"

  cluster_version           = var.cluster_version
  cluster_role_arn          = module.iam.cluster_role_arn
  node_role_arn             = module.iam.node_role_arn
  subnet_ids                = module.network.public_subnet_ids
  cluster_security_group_id = module.network.cluster_security_group_id

  depends_on = [module.iam, module.network]
}
