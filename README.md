# Nexa Digital – Automated Static Site Deployment Pipeline

## Overview
An automated CI/CD pipeline for deploying a static website to AWS using GitHub Actions, Terraform, Amazon S3 and CloudFront.

## Live Environments
- Production: https://d1boyno30oi52g.cloudfront.net
- Preview: https://d1boyno30oi52g.cloudfront.net/preview/

## Architecture

```mermaid
flowchart TD
    A[GitHub Repository] --> B{Branch}
    B -->|feature/*| C[Validation]
    B -->|develop| D[Validate and Deploy Preview]
    B -->|main| E[Validate and Deploy Production]
    D --> F[OIDC Preview IAM Role]
    E --> G[OIDC Production IAM Role]
    F --> H[Preview S3 Bucket]
    G --> I[Production S3 Bucket]
    H --> J[CloudFront Preview Path]
    I --> K[CloudFront Default Origin]
    J --> L[Website Visitors]
    K --> L
Technologies
- AWS S3 and CloudFront
- AWS IAM and OpenID Connect
- Terraform
- Git and GitHub
- GitHub Actions
- HTML and CSS
- Linux / Ubuntu (WSL)
Deployment Workflow
Branch	Action
feature/*	Validation only
develop	Validation and preview deployment
main	Validation and production deployment

GitHub Actions validates the website before deployment. AWS authentication uses GitHub OIDC rather than long-lived AWS access keys.
AWS Infrastructure
Terraform manages:
- Two private S3 buckets for preview and production.
- S3 public access blocks and AES-256 encryption.
- CloudFront distribution with two S3 origins.
- CloudFront Origin Access Control.
- CloudFront Function for preview path rewriting.
- GitHub OIDC provider and separate deployment IAM roles.
Security
- S3 buckets are private.
- CloudFront accesses S3 through OAC.
- Separate IAM roles are used for preview and production.
- IAM permissions are scoped to deployment resources.
- Terraform state and plan files are excluded from Git.
Local Testing
python3 -m http.server 8000 --directory site


Open http://localhost:8000.
Project Outcomes
- Built and deployed a responsive static website.
- Automated validation and branch-based deployment.
- Implemented separate preview and production environments.
- Provisioned AWS infrastructure using Terraform.
- Configured secure GitHub-to-AWS authentication with OIDC.
- Tested preview and production deployment isolation.
Cost Considerations
S3 and CloudFront may incur AWS charges. The distribution uses PriceClass_100. Monitor AWS Billing and Cost Explorer.
Repository
https://github.com/drukpong/static-site-pipeline
