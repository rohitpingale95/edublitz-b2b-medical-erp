resource "aws_s3_bucket" "this" {
  bucket = var.domain_name

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_cloudfront_origin_access_control" "this" {
  name        = "${var.project_name}-oac"
  description = "CloudFront access to Medical ERP S3"

  origin_access_control_origin_type = "s3"

  signing_behavior = "always"
  signing_protocol = "sigv4"
}


resource "aws_cloudfront_distribution" "this" {
  enabled = true

  aliases = [
    var.domain_name
  ]

  origin {
    domain_name = aws_s3_bucket.this.bucket_regional_domain_name

    origin_id = "medical-erp-frontend"

    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id = "medical-erp-frontend"

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    # AWS Managed-CachingOptimized policy
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.certificate_arn

    ssl_support_method = "sni-only"

    minimum_protocol_version = "TLSv1.2_2021"
  }

  custom_error_response {
    error_code = 403

    response_code = 200

    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code = 404

    response_code = 200

    response_page_path = "/index.html"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


data "aws_iam_policy_document" "this" {
  statement {
    sid = "AllowCloudFrontRead"

    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.this.arn}/*"
    ]

    principals {
      type = "Service"

      identifiers = [
        "cloudfront.amazonaws.com"
      ]
    }

    condition {
      test = "StringEquals"

      variable = "AWS:SourceArn"

      values = [
        aws_cloudfront_distribution.this.arn
      ]
    }
  }
}


resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  policy = data.aws_iam_policy_document.this.json
}


resource "aws_route53_record" "frontend" {
  zone_id = var.zone_id

  name = var.domain_name

  type = "A"

  alias {
    name = aws_cloudfront_distribution.this.domain_name

    zone_id = aws_cloudfront_distribution.this.hosted_zone_id

    evaluate_target_health = false
  }
}