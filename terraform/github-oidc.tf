
# GitHub Actions OIDC identity provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

# Trust policy for production deployments from main
data "aws_iam_policy_document" "github_production_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:Drukpong/static-site-pipeline:ref:refs/heads/main"]
    }
  }
}

# Trust policy for preview deployments from develop
data "aws_iam_policy_document" "github_preview_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:Drukpong/static-site-pipeline:ref:refs/heads/develop"]
    }
  }
}

# Production deployment role
resource "aws_iam_role" "github_production" {
  name               = "${var.project_name}-github-production"
  assume_role_policy = data.aws_iam_policy_document.github_production_assume_role.json
}

# Preview deployment role
resource "aws_iam_role" "github_preview" {
  name               = "${var.project_name}-github-preview"
  assume_role_policy = data.aws_iam_policy_document.github_preview_assume_role.json
}

# Production role permissions
data "aws_iam_policy_document" "github_production_permissions" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.production.arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${aws_s3_bucket.production.arn}/*"
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

# Preview role permissions
data "aws_iam_policy_document" "github_preview_permissions" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.preview.arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${aws_s3_bucket.preview.arn}/*"
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

# Attach permissions to production role
resource "aws_iam_role_policy" "github_production" {
  name   = "${var.project_name}-github-production-policy"
  role   = aws_iam_role.github_production.id
  policy = data.aws_iam_policy_document.github_production_permissions.json
}

# Attach permissions to preview role
resource "aws_iam_role_policy" "github_preview" {
  name   = "${var.project_name}-github-preview-policy"
  role   = aws_iam_role.github_preview.id
  policy = data.aws_iam_policy_document.github_preview_permissions.json
}

# Outputs for GitHub Actions configuration
output "github_production_role_arn" {
  value       = aws_iam_role.github_production.arn
  description = "IAM role for GitHub main branch production deployments"
}

output "github_preview_role_arn" {
  value       = aws_iam_role.github_preview.arn
  description = "IAM role for GitHub develop branch preview deployments"
}
