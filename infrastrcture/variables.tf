variable "project_name" {
  description = "Project name prefix. Used for naming and subdomain derivation."
  type        = string
  default     = "document-verifier"
}

variable "parent_zone_name" {
  description = "Public Route 53 hosted zone domain (e.g., example.com)."
  type        = string
}

variable "custom_domain_name" {
  description = "Optional full domain name overriding the default convention '<project_name>-api.<parent_zone_name>'."
  type        = string
  default     = ""
}

variable "cloudfront_acm_certificate_arn" {
  description = "Existing ACM certificate ARN to use for CloudFront must be in us-east-1. Terraform will not create or validate the certificate."
  type        = string
}

variable "cloudfront_acm_certificate_region" {
  description = "Region of the ACM certificate for CloudFront must be us-east-1."
  type        = string
  default     = "us-east-1"
  validation {
    condition     = lower(var.cloudfront_acm_certificate_region) == "us-east-1"
    error_message = "CloudFront requires the ACM certificate to be in us-east-1."
  }
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "salmanhabibkhan"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "paynest-document-verifier-api"
}

variable "github_branch" {
  description = "Branch to build/deploy"
  type        = string
  default     = "main"
}

variable "malicious_ip_cidrs" {
  description = "List of malicious IP CIDRs to block with WAF"
  type        = list(string)
  default     = []
}

variable "verification_api_key_secret_arn" {
  description = "ARN of an existing Secrets Manager secret containing the verification API key. Value changes are managed manually in Secrets Manager."
  type        = string
}

variable "extra_runtime_environment_secrets" {
  description = "Optional map of additional environment secrets where key is ENV var name and value is Secrets Manager ARN."
  type        = map(string)
  default     = {}
}

variable "extra_runtime_environment_variables" {
  description = "Optional map of additional non-secret environment variables."
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "Primary AWS region for resources (App Runner, ECR, CodeBuild, CodePipeline, etc.)"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    Project   = "PayNest"
    Service   = "document-verifier-api"
    ManagedBy = "Terraform Infrastrcture"
  }
}

variable "ecr_repository_name" {
  description = "Name of the existing manually created ECR repository, e.g, document-verifier"
  type        = string
}