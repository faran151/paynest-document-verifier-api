variable "repo_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "lifecycle_policy_text" {
  description = "ECR lifecycle policy JSON. If empty, a sane default is applied."
  type        = string
  default     = <<-JSON
  {
    "rules": [
      {
        "rulePriority": 1,
        "description": "Keep last 10 images (any tag)",
        "selection": {
          "tagStatus": "any",
          "countType": "imageCountMoreThan",
          "countNumber": 10
        },
        "action": { "type": "expire" }
      }
    ]
  }
  JSON
}