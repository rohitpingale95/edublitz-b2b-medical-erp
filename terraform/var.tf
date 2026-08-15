variable "aws_region" {
  description = "Main AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "medical-erp"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "my-eks-cluster1"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "domain_name" {
  description = "Frontend domain"
  type        = string
  default     = "mayurcbz.space"
}

variable "api_domain_name" {
  description = "Backend API domain"
  type        = string
  default     = "api.mayurcbz.space"
}

