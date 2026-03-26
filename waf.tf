resource "aws_wafv2_ip_set" "allowed" {
  count    = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  provider = aws.us_east_1

  name               = "${local.name_prefix}-allowed-ips"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = var.allowed_cidr_blocks

  tags = local.common_tags
}

resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1

  name  = "${local.name_prefix}-waf"
  scope = "CLOUDFRONT"

  default_action {
    dynamic "allow" {
      for_each = length(var.allowed_cidr_blocks) == 0 ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
      content {}
    }
  }

  dynamic "rule" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      name     = "allow-cidr"
      priority = 0

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowed[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "allow-cidr"
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "amazon-ip-reputation"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "amazon-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "rate-limit"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        aggregate_key_type = "IP"
        limit              = var.waf_rate_limit
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }
}
