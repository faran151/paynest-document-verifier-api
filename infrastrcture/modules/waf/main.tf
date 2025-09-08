data "aws_caller_identity" "current" {}

resource "aws_wafv2_ip_set" "malicious" {
  name               = "${var.name_prefix}-malicious-ips"
  description        = "Blocked IPs"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = var.malicious_ip_cidrs
  tags               = var.tags
}

resource "aws_wafv2_web_acl" "this" {
  name        = "${var.name_prefix}-web-acl"
  description = "Web ACL for CloudFront"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "BlockMaliciousIPs"
    priority = 1
    action {
      block {}
    }
    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.malicious.arn
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-block-malicious"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

resource "aws_s3_bucket" "waf_logs" {
  count         = var.enable_logging ? 1 : 0
  bucket        = "${var.name_prefix}-waf-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "waf_logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.waf_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "waf_logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.waf_logs[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "firehose_assume" {
  count = var.enable_logging ? 1 : 0
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "firehose_waf" {
  count              = var.enable_logging ? 1 : 0
  name               = "${var.name_prefix}-firehose-waf-logs"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "firehose_waf" {
  count = var.enable_logging ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [
      aws_s3_bucket.waf_logs[0].arn,
      "${aws_s3_bucket.waf_logs[0].arn}/*"
    ]
  }
}

resource "aws_iam_policy" "firehose_waf" {
  count  = var.enable_logging ? 1 : 0
  name   = "${var.name_prefix}-firehose-waf"
  policy = data.aws_iam_policy_document.firehose_waf[0].json
}

resource "aws_iam_role_policy_attachment" "firehose_waf" {
  count      = var.enable_logging ? 1 : 0
  role       = aws_iam_role.firehose_waf[0].name
  policy_arn = aws_iam_policy.firehose_waf[0].arn
}

resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  count       = var.enable_logging ? 1 : 0
  name        = "${var.name_prefix}-waf-logs"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_waf[0].arn
    bucket_arn          = aws_s3_bucket.waf_logs[0].arn
    prefix              = "AWSLogs/AWSWAF/"
    error_output_prefix = "AWSLogs/AWSWAF/processing-failed/!{firehose:error-output-type}/"
    compression_format  = "GZIP"
    buffering_size      = 5
    buffering_interval  = 300
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count                   = var.enable_logging ? 1 : 0
  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.waf_logs[0].arn]
}

resource "aws_wafv2_web_acl_association" "cf_assoc" {
  # Use the exact ARN from CloudFront, don't build it by hand
  resource_arn = trimspace(var.cloudfront_arn)
  web_acl_arn  = aws_wafv2_web_acl.this.arn
  count = 0
}