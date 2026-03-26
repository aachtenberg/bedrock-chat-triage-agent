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

# Random suffix for globally-unique resource names (S3 buckets, Cognito domain).
resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false
}

# Session secret injected into the CloudFront Function and the auth Lambda.
# Both use it to sign and verify HMAC-SHA256 session cookies.
resource "random_password" "session_secret" {
  length  = 32
  special = false
}
