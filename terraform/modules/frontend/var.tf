variable "domain_name" {
  description = "Frontend domain and S3 bucket name"
  type        = string
}

variable "zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for CloudFront"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "bucket_name" {
  description = "Frontend S3 bucket name"
  type        = string
}