data "aws_caller_identity" "current" {}

locals {
  production_bucket = "${var.project_name}-prod-${data.aws_caller_identity.current.account_id}"
  preview_bucket    = "${var.project_name}-preview-${data.aws_caller_identity.current.account_id}"
}

# Production S3 bucket
resource "aws_s3_bucket" "production" {
  bucket = local.production_bucket
}

# Preview S3 bucket
resource "aws_s3_bucket" "preview" {
  bucket = local.preview_bucket
}

# Block public access on both buckets
resource "aws_s3_bucket_public_access_block" "production" {
  bucket                  = aws_s3_bucket.production.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "preview" {
  bucket                  = aws_s3_bucket.preview.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "production" {
  bucket = aws_s3_bucket.production.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "preview" {
  bucket = aws_s3_bucket.preview.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-oac"
  description                       = "Secure access to private website buckets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Rewrite /preview/... to /... before requesting from preview bucket
resource "aws_cloudfront_function" "preview_rewrite" {
  name    = "${var.project_name}-preview-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Remove the preview URL prefix"
  publish = true

  code = <<-EOT
    function handler(event) {
      var request = event.request;

      if (request.uri === '/preview') {
        request.uri = '/';
      } else if (request.uri.startsWith('/preview/')) {
        request.uri = request.uri.substring('/preview'.length);
      }

      return request;
    }
  EOT
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  comment             = "${var.project_name} website distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.production.bucket_regional_domain_name
    origin_id                = "production-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  origin {
    domain_name              = aws_s3_bucket.preview.bucket_regional_domain_name
    origin_id                = "preview-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "production-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/preview*"
    target_origin_id       = "preview-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.preview_rewrite.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  depends_on = [
    aws_s3_bucket_public_access_block.production,
    aws_s3_bucket_public_access_block.preview
  ]
}

# Permit this CloudFront distribution to read production objects
resource "aws_s3_bucket_policy" "production" {
  bucket = aws_s3_bucket.production.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontRead"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.production.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
        }
      }
    }]
  })
}

# Permit this CloudFront distribution to read preview objects
resource "aws_s3_bucket_policy" "preview" {
  bucket = aws_s3_bucket.preview.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontRead"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.preview.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
        }
      }
    }]
  })
}
