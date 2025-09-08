variable "name_prefix" { type = string }
variable "github_owner" { type = string }
variable "github_repo" { type = string }
variable "github_branch" { type = string }
variable "artifact_bucket_arn" { type = string }
variable "artifact_bucket_name" { type = string }
variable "ecr_repo_arn" { type = string }
variable "ecr_repo_name" { type = string }
variable "apprunner_service_arn" { type = string }
variable "region" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}