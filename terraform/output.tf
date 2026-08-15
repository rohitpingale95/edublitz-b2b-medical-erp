output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnet_ids
}

output "public_subnets" {
  value = module.vpc.public_subnet_ids
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repositories" {
  value = module.ecr.repository_urls
}

output "frontend_bucket" {
  value = module.frontend.bucket_name
}

output "cloudfront_domain" {
  value = module.frontend.cloudfront_domain_name
}

output "frontend_url" {
  value = module.frontend.frontend_url
}

output "frontend_certificate_arn" {
  value = module.frontend_acm.certificate_arn
}

output "backend_certificate_arn" {
  value = module.backend_acm.certificate_arn
}

output "route53_nameservers" {
  value = module.route53.name_servers
}

