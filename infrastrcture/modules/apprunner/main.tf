data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "apprunner_access_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["build.apprunner.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "apprunner_access" {
  name               = "${var.name_prefix}-apprunner-access"
  assume_role_policy = data.aws_iam_policy_document.apprunner_access_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "apprunner_instance_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["tasks.apprunner.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "apprunner_instance" {
  name               = "${var.name_prefix}-apprunner-instance"
  assume_role_policy = data.aws_iam_policy_document.apprunner_instance_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "apprunner_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = length(var.runtime_environment_secrets) > 0 ? values(var.runtime_environment_secrets) : ["arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:*"]
  }

  statement {
    effect = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.id}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "apprunner" {
  name_prefix = "${var.name_prefix}-apprunner-access-"
  policy      = data.aws_iam_policy_document.apprunner_policy.json
}

resource "aws_iam_role_policy_attachment" "apprunner_access_attach" {
  role       = aws_iam_role.apprunner_access.name
  policy_arn = aws_iam_policy.apprunner.arn
}

resource "aws_iam_role_policy_attachment" "apprunner_instance_attach" {
  role       = aws_iam_role.apprunner_instance.name
  policy_arn = aws_iam_policy.apprunner.arn
}

resource "aws_apprunner_auto_scaling_configuration_version" "this" {
  auto_scaling_configuration_name = "${var.name_prefix}-asc"
  max_concurrency                 = 100
  max_size                        = 5
  min_size                        = 1
  tags                            = var.tags
}

resource "aws_apprunner_service" "this" {
  service_name = "${var.name_prefix}-svc"

  source_configuration {
    auto_deployments_enabled = var.bootstrap_image_repository_type == "ECR"

    image_repository {
      image_identifier      = var.bootstrap_image_identifier
      image_repository_type = var.bootstrap_image_repository_type
      image_configuration {
        port = tostring(var.container_port)
        runtime_environment_variables = merge(
          var.runtime_environment_variables,
          {
            PORT      = tostring(var.container_port)
            LOG_LEVEL = lower(lookup(var.runtime_environment_variables, "LOG_LEVEL", "info"))
          }
        )
        runtime_environment_secrets = var.runtime_environment_secrets
      }
    }

    dynamic "authentication_configuration" {
      for_each = var.bootstrap_image_repository_type == "ECR" ? [1] : []
      content {
        access_role_arn = aws_iam_role.apprunner_access.arn
      }
    }
  }

  health_check_configuration {
    protocol            = "TCP"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }

  instance_configuration {
    cpu               = "1 vCPU"
    memory            = "2 GB"
    instance_role_arn = aws_iam_role.apprunner_instance.arn
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.this.arn

  tags = var.tags
}

output "service_url" {
  value = aws_apprunner_service.this.service_url
}

output "service_domain_name" {
  value = aws_apprunner_service.this.service_url != "" ? replace(aws_apprunner_service.this.service_url, "https://", "") : ""
}

output "service_arn" {
  value = aws_apprunner_service.this.arn
}