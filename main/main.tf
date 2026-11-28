module "iam" {
  source     = "../modules/iam"
  depends_on = [module.identity_center]
}

module "network" {
  source     = "../modules/network"
  depends_on = [module.iam]
}

module "cluster" {
  source = "../modules/cluster"

  cluster_version               = var.cluster_version
  bootstrap_self_managed_addons = var.bootstrap_self_managed_addons
  cluster_role_arn              = module.iam.cluster_role_arn
  node_role_arn                 = module.iam.node_role_arn
  subnet_ids                    = module.network.public_subnet_ids
  cluster_security_group_id     = module.network.cluster_security_group_id

  depends_on = [module.iam, module.network]
}

module "eks_capabilities" {
  source = "../modules/eks_capabilities"

  cluster_name     = module.cluster.cluster_name
  ci_principal_arn = var.ci_principal_arn

  depends_on = [module.cluster]
}

module "argocd" {
  source = "../modules/argocd"
  count  = var.enable_managed_argocd ? 0 : 1

  cluster_name    = module.cluster.cluster_name
  region          = var.aws_region
  oidc_issuer_url = module.cluster.oidc_issuer_url

  depends_on = [module.cluster, module.eks_capabilities]
}
