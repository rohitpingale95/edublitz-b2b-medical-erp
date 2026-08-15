module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}


module "eks" {
  source = "./modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id = module.vpc.vpc_id

  # EKS worker nodes will be created in PUBLIC subnets
  subnet_ids = module.vpc.public_subnet_ids
}


module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name

  repositories = [
    "users-service",
    "products-service",
    "orders-service"
  ]
}


module "route53" {
  source = "./modules/route53"

  domain_name  = var.domain_name
  project_name = var.project_name
}


# Frontend ACM certificate
# CloudFront requires this certificate in us-east-1
module "frontend_acm" {
  source = "./modules/acm"

  domain_name = var.domain_name

  zone_id = module.route53.zone_id

  project_name = var.project_name
  environment  = var.environment

  providers = {
    aws = aws.us_east_1
  }
}


# Backend ACM certificate
# ALB is in Oregon, so certificate is in us-west-2
module "backend_acm" {
  source = "./modules/acm"

  domain_name = var.api_domain_name

  zone_id = module.route53.zone_id

  project_name = var.project_name
  environment  = var.environment

  providers = {
    aws = aws
  }
}


# Frontend:
# S3 + CloudFront + Route53
module "frontend" {
  source = "./modules/frontend"

  domain_name = var.domain_name

  zone_id = module.route53.zone_id

  certificate_arn = module.frontend_acm.certificate_arn

  project_name = var.project_name
  environment  = var.environment

  depends_on = [
    module.frontend_acm
  ]
}


# AWS Load Balancer Controller
module "alb_controller" {
  source = "./modules/alb-controller"

  cluster_name = module.eks.cluster_name

  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url

  region = var.aws_region

  vpc_id = module.vpc.vpc_id

  depends_on = [
    module.eks
  ]
}