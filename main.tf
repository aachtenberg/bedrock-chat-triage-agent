data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_bedrockagent_agent_versions" "chat" {
  agent_id = aws_bedrockagent_agent.chat.agent_id
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  provider = aws.us_east_1
  name     = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  provider = aws.us_east_1
  name     = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host_header" {
  provider = aws.us_east_1
  name     = "Managed-AllViewerExceptHostHeader"
}

resource "aws_secretsmanager_secret" "basic_auth" {
  name                    = var.basic_auth_secret_name
  recovery_window_in_days = var.basic_auth_secret_recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "basic_auth" {
  secret_id = aws_secretsmanager_secret.basic_auth.id
  secret_string = jsonencode({
    (var.basic_auth_secret_username_key) = var.basic_auth_username
    (var.basic_auth_secret_password_key) = var.basic_auth_password
    (var.basic_auth_secret_realm_key)    = var.basic_auth_realm
  })
}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false
}
