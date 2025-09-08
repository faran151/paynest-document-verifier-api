variable "name_prefix" {
  type = string
}

variable "bootstrap_image_identifier" {
  description = "Initial image to start the service; pipeline can update this later."
  type        = string
  default     = "public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest"
}

variable "bootstrap_image_repository_type" {
  description = "ECR (private) or ECR_PUBLIC."
  type        = string
  default     = "ECR_PUBLIC"
}

variable "runtime_environment_secrets" {
  description = "Map of env var name -> Secrets Manager ARN"
  type        = map(string)
  default     = {}
}

variable "runtime_environment_variables" {
  description = "Map of plain env vars"
  type        = map(string)
  default     = {}
}

variable "container_port" {
  description = "Container listening port for App Runner."
  type        = number
  default     = 80
}

variable "tags" {
  type    = map(string)
  default = {}
}