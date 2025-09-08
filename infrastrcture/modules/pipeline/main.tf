resource "aws_codestarconnections_connection" "github" {
  name          = "${var.name_prefix}-github-conn"
  provider_type = "GitHub"
  tags          = var.tags
}

# IAM roles
data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "${var.name_prefix}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:PutObjectAcl", "s3:ListBucket", "s3:GetBucketVersioning"
    ]
    resources = [
      var.artifact_bucket_arn,
      "${var.artifact_bucket_arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = ["codebuild:BatchGetBuilds","codebuild:StartBuild"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = ["codestar-connections:UseConnection"]
    resources = [aws_codestarconnections_connection.github.arn]
  }
}

resource "aws_iam_policy" "codepipeline" {
  name   = "${var.name_prefix}-codepipeline"
  policy = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_iam_role_policy_attachment" "codepipeline_attach" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipeline.arn
}

# CodeBuild roles
data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuild_build" {
  name               = "${var.name_prefix}-codebuild-build-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = var.tags
}

resource "aws_iam_role" "codebuild_deploy" {
  name               = "${var.name_prefix}-codebuild-deploy-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codebuild_build" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject","s3:GetObjectVersion","s3:PutObject","s3:ListBucket"
    ]
    resources = [
      var.artifact_bucket_arn,
      "${var.artifact_bucket_arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "codebuild_build" {
  name   = "${var.name_prefix}-codebuild-build"
  policy = data.aws_iam_policy_document.codebuild_build.json
}

resource "aws_iam_role_policy_attachment" "codebuild_build_attach" {
  role       = aws_iam_role.codebuild_build.name
  policy_arn = aws_iam_policy.codebuild_build.arn
}

data "aws_iam_policy_document" "codebuild_deploy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject","s3:GetObjectVersion","s3:PutObject","s3:ListBucket"
    ]
    resources = [
      var.artifact_bucket_arn,
      "${var.artifact_bucket_arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "apprunner:UpdateService",
      "apprunner:StartDeployment",
      "apprunner:DescribeService"
    ]
    resources = [var.apprunner_service_arn]
  }
}

resource "aws_iam_policy" "codebuild_deploy" {
  name   = "${var.name_prefix}-codebuild-deploy"
  policy = data.aws_iam_policy_document.codebuild_deploy.json
}

resource "aws_iam_role_policy_attachment" "codebuild_deploy_attach" {
  role       = aws_iam_role.codebuild_deploy.name
  policy_arn = aws_iam_policy.codebuild_deploy.arn
}

# CodeBuild projects
resource "aws_codebuild_project" "build" {
  name         = "${var.name_prefix}-build"
  service_role = aws_iam_role.codebuild_build.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
    environment_variable {
      name  = "IMAGE_NAME"
      value = var.ecr_repo_name
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "pipeline/buildspec-build.yml"
  }
  cache {
    type = "NO_CACHE"
  }
  tags = var.tags
}

resource "aws_codebuild_project" "deploy" {
  name         = "${var.name_prefix}-deploy"
  service_role = aws_iam_role.codebuild_deploy.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
    environment_variable {
      name  = "APP_RUNNER_SERVICE_ARN"
      value = var.apprunner_service_arn
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "pipeline/appspec-deploy.yml"
  }
  cache {
    type = "NO_CACHE"
  }
  tags = var.tags
}

# CodePipeline
resource "aws_codepipeline" "this" {
  name     = "${var.name_prefix}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn
  artifact_store {
    type     = "S3"
    location = var.artifact_bucket_name
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Docker_Build_and_Push"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "AppRunner_Deploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["build_output"]
      version         = "1"
      configuration = {
        ProjectName = aws_codebuild_project.deploy.name
      }
    }
  }

  tags = var.tags
}