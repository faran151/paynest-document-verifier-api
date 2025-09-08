variable "name_prefix" {
  type = string
}

variable "origin_domain_name" {
  description = "The App Runner service domain (e.g., xyz123.us-east-1.awsapprunner.com)."
  type        = string
}

variable "domain_name" {
  description = "Viewer-facing domain (leave empty to use only the CloudFront domain)."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM cert in us-east-1 for the viewer domain."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "waf_web_acl_arn" {
  description = "Optional WAFv2 Web ACL ARN to attach to the distribution."
  type        = string
  default     = ""
}

variable "origin_forward_headers" {
  description = "Specific viewer headers to forward to the origin (e.g., [\"Authorization\"]). Host is not allowed."
  type        = list(string)
  default     = []
}