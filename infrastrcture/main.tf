locals {
  name_prefix         = var.project_name
  derived_domain_name = "${var.project_name}-api.${var.parent_zone_name}"
  domain_name         = var.custom_domain_name != "" ? var.custom_domain_name : local.derived_domain_name

  runtime_env_secrets = var.verification_api_key_secret_arn != "" ? merge({ VERIFICATION_API_KEY = var.verification_api_key_secret_arn }, var.extra_runtime_environment_secrets) : var.extra_runtime_environment_secrets
  runtime_env_vars = merge({ LOG_LEVEL = "info" }, var.extra_runtime_environment_variables)
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${local.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

data "aws_route53_zone" "parent" {
  name         = var.parent_zone_name
  private_zone = false
}

data "aws_ecr_repository" "existing" {
  name = var.ecr_repository_name
}

module "apprunner" {
  source      = "./modules/apprunner"
  name_prefix = local.name_prefix

  bootstrap_image_identifier      = "${data.aws_ecr_repository.existing.repository_url}:prod"
  bootstrap_image_repository_type = "ECR"
  container_port                  = 8000

  runtime_environment_secrets   = local.runtime_env_secrets
  runtime_environment_variables = local.runtime_env_vars
  tags                          = var.tags
}

module "edge" {
  source    = "./modules/cloudfront"
  providers = { aws = aws.us_east_1 }

  name_prefix         = local.name_prefix
  origin_domain_name  = module.apprunner.service_domain_name
  domain_name         = local.domain_name
  acm_certificate_arn = var.cloudfront_acm_certificate_arn

  # Attach WAF directly here (optional):
  waf_web_acl_arn     = try(module.waf.web_acl_arn, "")

  tags = var.tags
}

module "waf" {
  source    = "./modules/waf"
  providers = { aws = aws.us_east_1 }

  name_prefix        = local.name_prefix
  malicious_ip_cidrs = var.malicious_ip_cidrs
  tags               = var.tags
}

module "dns" {
  source            = "./modules/route53"
  domain_name       = local.domain_name
  zone_id           = data.aws_route53_zone.parent.zone_id
  cf_domain_name    = module.edge.cloudfront_domain_name
  cf_hosted_zone_id = module.edge.cloudfront_hosted_zone_id
  tags              = var.tags
}

module "pipeline" {
  source                = "./modules/pipeline"
  name_prefix           = local.name_prefix
  github_owner          = var.github_owner
  github_repo           = var.github_repo
  github_branch         = var.github_branch
  artifact_bucket_arn   = aws_s3_bucket.artifacts.arn
  artifact_bucket_name  = aws_s3_bucket.artifacts.id
  ecr_repo_arn          = data.aws_ecr_repository.existing.arn
  ecr_repo_name         = data.aws_ecr_repository.existing.name
  apprunner_service_arn = module.apprunner.service_arn
  region                = var.region
  tags                  = var.tags
}