resource "aws_dynamodb_table" "otp_codes" {
  count = local.otp_enabled ? 1 : 0

  name         = "${local.name_prefix}-otp-codes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = local.common_tags
}
