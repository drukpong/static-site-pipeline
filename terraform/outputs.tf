output "production_bucket_name" {
  description = "Production S3 bucket"
  value       = aws_s3_bucket.production.bucket
}

output "preview_bucket_name" {
  description = "Preview S3 bucket"
  value       = aws_s3_bucket.preview.bucket
}

output "cloudfront_url" {
  description = "Public website URL"
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.site.id
}
