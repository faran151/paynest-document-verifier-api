resource "aws_secretsmanager_secret" "verification_api_key" {
  name                    = "${var.name_prefix}/verification_api_key"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "verification_api_key" {
  count     = var.create_secret_value != "" ? 1 : 0
  secret_id = aws_secretsmanager_secret.verification_api_key.id
  secret_string = var.create_secret_value
}